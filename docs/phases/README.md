# Ejecutar las fases 2, 3 y 4 en Cloud Shell

El código está preparado para las tres fases. Las pruebas reales y sus evidencias se generan al ejecutarlas en tu proyecto; los resultados esperados de estas guías no son resultados observados.

| Fase | Selección | Recursos adicionales | Guía |
| --- | --- | --- | --- |
| 2 | `lab_phase=2` | VM Debian privada, IAP, OS Login, firewall SSH | [Acceso seguro](phase2.md) |
| 3 | `lab_phase=3` | Subred `/26`, VM HTTP privada, Job con Direct VPC egress | [Conectividad privada](phase3.md) |
| 4 | `lab_phase=4` | Dos buckets privados, identidad y Job de autorización | [Mínimo privilegio](phase4.md) |

Solo se activa una fase a la vez. La VPC, la subred `10.10.10.0/24`, la identidad y el servicio Cloud Run originales son comunes. El servicio original no se conecta a la VPC; en la fase 3 se añade un Job distinto.

**Cambiar `lab_phase` puede eliminar recursos de la fase anterior.** Completa pruebas y limpieza antes de cambiar de fase. No uses `-target` para separar fases.

## Preparación común

Utiliza un proyecto de laboratorio con facturación habilitada. El despliegue necesita permisos para habilitar APIs, gestionar red/VMs, Cloud Run, buckets, cuentas de servicio y sus políticas IAM; la fase 2 también crea un rol personalizado y bindings de proyecto. Esos permisos corresponden al operador de Terraform, no a las identidades de las aplicaciones. El código no concede a las aplicaciones roles de administrador ni crea claves.

Sigue primero la [comprobación de la instalación](../getting-started.md). En Cloud Shell:

```bash
cd ~/CloudFortress
git pull --ff-only
cd infra/terraform

export TF_BIN=/usr/bin/terraform
"$TF_BIN" version
export TF_VAR_project_id="$(gcloud config get-value project)"
export TF_VAR_region=europe-west1
export TF_VAR_zone=europe-west1-b
printf 'Proyecto: %s; región: %s; zona: %s\n' \
  "$TF_VAR_project_id" "$TF_VAR_region" "$TF_VAR_zone"
```

Si el ejecutable está en otra ruta, cambia `TF_BIN`. Detente si el proyecto está vacío, indica `(unset)` o no es el proyecto del laboratorio. Selecciónalo con `gcloud config set project TU_PROJECT_ID` y vuelve a exportar la variable. Mantén región y zona coherentes; puedes usar otra zona disponible de esa región.

El proyecto debe tener Service Usage habilitado; si fuera necesario y tienes permisos:

```bash
gcloud services enable serviceusage.googleapis.com --project="$TF_VAR_project_id"
```

Terraform habilita Compute Engine, IAM, IAP, OS Login, Cloud Run, Cloud Storage y Cloud Logging, y conserva las APIs al destruir el laboratorio para no afectar otros servicios.

```bash
"$TF_BIN" init
"$TF_BIN" fmt -check -recursive
"$TF_BIN" validate
set -o pipefail
export EVIDENCE="$(cd ../.. && pwd)/docs/evidence/raw/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
```

Ejecuta cada comando por separado y detente ante errores. Repite estas exportaciones si abres una sesión nueva. También puedes conservar valores en `terraform.tfvars` local, excluido de Git. Las variables de entorno prevalecen sobre valores por defecto, pero un archivo `.tfvars` puede prevalecer sobre ellas: evita definir la misma variable en ambos sitios.

## Plan y despliegue: en cada cambio

Después de seleccionar la fase o cambiar un control, ejecuta:

```bash
"$TF_BIN" plan -out=tfplan
"$TF_BIN" show -no-color tfplan | tee "$EVIDENCE/plan-$(date -u +%Y%m%dT%H%M%SZ).txt"
```

Revisa proyecto, región, altas/bajas, IP públicas, fuentes/puertos del firewall e IAM. Las VMs no deben tener `access_config`. Calcula el coste previsto de VM, disco, Cloud Run, almacenamiento y logs. **No ejecutes `apply` sin revisar primero este plan.** Cuando lo hayas revisado y quieras desplegar exactamente esos cambios, ejecuta por separado:

```bash
"$TF_BIN" apply tfplan
```

No incluyas `apply` en un pegado automático junto al plan. Si cambias variables o configuración, genera y revisa otro plan.

## Guardar logs de un Job

Las guías indican cuándo ejecutar cada Job. Después de cada ejecución, guarda sus detalles y logs antes de iniciar otra. No ejecutes el mismo Job en paralelo durante el laboratorio:

```bash
# JOB y STAGE se definen en la guía de la fase.
EXECUTION="$(gcloud run jobs executions list --job="$JOB" \
  --project="$TF_VAR_project_id" --region="$TF_VAR_region" \
  --sort-by='~metadata.creationTimestamp' --limit=1 --format='value(metadata.name)')"
EXECUTION="${EXECUTION##*/}"
test -n "$EXECUTION"

gcloud run jobs executions describe "$EXECUTION" \
  --project="$TF_VAR_project_id" --region="$TF_VAR_region" \
  --format=json > "$EVIDENCE/$STAGE-execution.json"

gcloud logging read \
  "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"$JOB\" AND labels.\"run.googleapis.com/execution_name\"=\"$EXECUTION\"" \
  --project="$TF_VAR_project_id" --freshness=1h --order=asc --limit=200 \
  --format=json > "$EVIDENCE/$STAGE-logs.json"
```

Si `test -n` falla, detente: no selecciones logs de otro Job. Los logs pueden tardar en aparecer; repite la lectura sin volver a ejecutar el Job. Los permisos para consultar logs son independientes de los permisos de la identidad del contenedor.

## Evidencias, GitHub y limpieza

Al terminar cada fase, copia [la plantilla de evidencia](../evidence/README.md) a `docs/evidence/phaseN-results.md`, completa solo los resultados observados y revisa los datos antes de publicarlos. Los logs originales en `docs/evidence/raw/` están excluidos de Git. Conserva allí el plan y los fallos; no publiques tokens, claves, estados ni planes binarios.

Sube el código y el resumen revisado desde la raíz del repositorio:

```bash
cd ~/CloudFortress
git status --short
# Añade explícitamente los archivos de código/documentación que hayas cambiado.
git add docs/evidence/phaseN-results.md
git diff --cached
git commit -m "docs: record phase N lab evidence"
git push origin main
cd infra/terraform
```

Sustituye `N` por la fase. Si solo has ejecutado Terraform, el código ya está versionado: añade únicamente el resumen. No comitees resultados esperados como si hubieran ocurrido.

Conserva las variables de la fase activa, incluyendo proyecto, zona y sufijo de buckets, y prepara la destrucción:

```bash
"$TF_BIN" plan -destroy -out=destroy.tfplan
"$TF_BIN" show -no-color destroy.tfplan | tee "$EVIDENCE/destroy-plan.txt"
```

Revisa que solo elimine recursos del laboratorio. Para ejecutar el equivalente a `terraform destroy` aplicando el plan de destrucción ya revisado:

```bash
"$TF_BIN" apply destroy.tfplan
"$TF_BIN" state list | tee "$EVIDENCE/state-after-destroy.txt"
```

El estado debe quedar vacío tras una destrucción completa. Las APIs permanecen habilitadas fuera del estado; su activación sola no genera consumo. Verifica además en Google Cloud que las VMs, discos, Jobs, buckets y el servicio del laboratorio han desaparecido. Los logs históricos y el borrado lógico de identidades/roles pueden persistir; no declares coste cero solo porque el comando finalizó. Guarda el resultado de limpieza en el resumen y sube ese último cambio.

No borres ni reemplaces el estado para empezar la fase siguiente. Si un bucket tiene objetos ajenos a Terraform, la eliminación falla deliberadamente (`force_destroy=false`): revisa su contenido antes de eliminarlos. En la fase 3, liberar las IP de Direct VPC egress puede tardar varios minutos después de una ejecución; si la subred sigue en uso, espera y vuelve a planificar la limpieza conservando el estado.

## Comprobaciones locales del código

Sin credenciales ni llamadas a Google Cloud:

```bash
terraform -chdir=infra/terraform test
python3 -m unittest discover -s tests -v
```

Los tests de Terraform usan un proveedor simulado y únicamente planes. Comprueban controles declarados; no sustituyen las pruebas reales de IAP, routing, IAM y facturación.
