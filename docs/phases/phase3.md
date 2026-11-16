# Fase 3: conectividad privada entre Cloud Run y una VM

Archivo: [`phase3_private_connectivity.tf`](../../infra/terraform/phase3_private_connectivity.tf). Completa la limpieza de la fase anterior y la [preparación común](README.md).

## Seleccionar y desplegar

```bash
export TF_VAR_lab_phase=3
export TF_VAR_phase3_http_enabled=true
```

Genera, revisa y aplica el plan con el procedimiento común. Debe crear:

- Una subred `10.10.20.0/26` en la misma VPC y región que Cloud Run.
- Una VM Debian sin IP pública en `10.10.10.0/24`, que sirve `/health` en TCP/8080.
- Una identidad de VM y otra del Job sin permisos de aplicación.
- Un Job de Cloud Run con Direct VPC egress `PRIVATE_RANGES_ONLY`, sin conector ni Cloud NAT.
- Un firewall de entrada TCP/8080 desde `10.10.20.0/26`, dirigido únicamente a la identidad de la VM HTTP.

El servidor utiliza Python 3 y systemd con un usuario dinámico sin privilegios. El arranque no descarga paquetes: la imagen debe incluir `/usr/bin/python3`. El valor por defecto es Debian 12 de Google Cloud; si usas una imagen personalizada, incluye Python antes de crearla. No se habilita SSH hacia esta VM.

Direct VPC egress necesita una subred de al menos `/26`; su establecimiento inicial puede tardar. El cliente reintenta de forma acotada antes de fallar. Consulta [Direct VPC egress](https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc).

## Prueba positiva

```bash
export JOB=cloudfortress-network-probe
export STAGE=phase3-allowed
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Guarda los detalles y logs con [el bloque común de evidencias de Jobs](README.md#guardar-logs-de-un-job). Esperado: ejecución completada y `http_status: 200` en el evento `private_http`. La VM puede tardar en arrancar; si falla, inspecciona antes de repetir:

```bash
gcloud compute instances get-serial-port-output cloudfortress-http-vm \
  --project="$TF_VAR_project_id" --zone="$TF_VAR_zone" \
  > "$EVIDENCE/phase3-boot.txt"
```

Un fallo de descarga de imagen, arranque o autenticación del operador no es evidencia de un bloqueo del firewall. Puedes cambiar `python_container_image` por un registro permitido o un digest compatible con Python 3, y volver a revisar el plan.

## Bloquear y recuperar

```bash
export TF_VAR_phase3_http_enabled=false
```

Genera, revisa y aplica un plan que solo desactive `cloudfortress-private-http`. Después:

```bash
export STAGE=phase3-blocked
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Captura los logs de esa ejecución con el bloque común. Esperado: Job fallido tras los reintentos y eventos de error/timeout de `private_http`, sin HTTP 200. El fallo del Job es intencionado en esta prueba; inspecciona su causa.

```bash
export TF_VAR_phase3_http_enabled=true
```

Genera, revisa y aplica el plan de recuperación. Después:

```bash
export STAGE=phase3-restored
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Captura sus logs: debe volver a producir HTTP 200.

## Cerrar la fase

Incluye en el resumen la IP privada de la VM, la subred del Job, la regla aplicada y las tres ejecuciones. El [diagrama de arquitectura](../architecture/README.md) representa el recorrido. Sube las evidencias revisadas y realiza [la limpieza común](README.md#evidencias-github-y-limpieza).
