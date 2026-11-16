# Fase 2: VM privada y acceso administrativo seguro

Archivo: [`network_lab.tf`](../../infra/terraform/network_lab.tf). Sigue primero la [preparación común](README.md).

## Seleccionar y desplegar

```bash
export TF_VAR_lab_phase=2
export TF_VAR_operator_member="user:$(gcloud config get-value account)"
export TF_VAR_phase2_iap_ssh_enabled=true
printf 'Operador SSH: %s\n' "$TF_VAR_operator_member"
```

Verifica que sea una cuenta de usuario válida. Para otro operador o un grupo, establece explícitamente `user:EMAIL` o `group:EMAIL`. Si el operador pertenece a otra organización, un administrador puede necesitar conceder `roles/compute.osLoginExternalUser` en la organización; el laboratorio no lo gestiona.

Genera, revisa y aplica el plan siguiendo [el procedimiento común](README.md#plan-y-despliegue-en-cada-cambio).

El plan debe mostrar una VM Debian en `10.10.10.0/24`, sin IP pública, OS Login activado, una identidad sin roles de aplicación y un firewall TCP/22 desde `35.235.240.0/20`, dirigido únicamente a esa identidad. Se conceden OS Login sin sudo en la VM, acceso IAP a esa VM limitado al puerto 22, `serviceAccountUser` sobre su cuenta y un rol personalizado de lectura para descubrimiento con `gcloud`. Consulta [OS Login](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin) y [IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding).

## Prueba positiva

```bash
VM="$("$TF_BIN" output -json phase2 | python3 -c 'import json,sys; print(json.load(sys.stdin)["vm_name"])')"
gcloud compute instances describe "$VM" --zone="$TF_VAR_zone" \
  --project="$TF_VAR_project_id" --format=json > "$EVIDENCE/phase2-vm.json"

gcloud compute ssh "$VM" --zone="$TF_VAR_zone" --project="$TF_VAR_project_id" \
  --tunnel-through-iap --command='id; hostname' \
  --ssh-flag='-oControlMaster=no' --ssh-flag='-oControlPath=none' \
  --ssh-flag='-oConnectTimeout=20' 2>&1 | tee "$EVIDENCE/phase2-ssh-allowed.txt"
```

Resultado esperado: salida de `id` y hostname, sin IP pública en la descripción. La primera conexión puede pedir crear una clave SSH local; no es una clave de cuenta de servicio. Espera al arranque y a la propagación IAM si aparece un fallo inicial. No cambies OS Login ni abras SSH a Internet para resolverlo.

## Bloqueo y recuperación

```bash
export TF_VAR_phase2_iap_ssh_enabled=false
```

Genera y revisa un nuevo plan: debe cambiar `disabled` a `true` en `cloudfortress-iap-ssh`. Aplícalo después de revisarlo.

Prueba una conexión nueva:

```bash
gcloud compute ssh "$VM" --zone="$TF_VAR_zone" --project="$TF_VAR_project_id" \
  --tunnel-through-iap --command='id; hostname' \
  --ssh-flag='-oControlMaster=no' --ssh-flag='-oControlPath=none' \
  --ssh-flag='-oConnectTimeout=20' 2>&1 | tee "$EVIDENCE/phase2-ssh-blocked.txt"
```

Esperado: la **nueva** conexión falla por conectividad. Una sesión ya abierta puede continuar por el seguimiento de conexiones del firewall; no sirve como prueba negativa. Un error de IAM, cuenta o configuración no demuestra el bloqueo de red. Si tarda demasiado, cancela el intento y registra el timeout.

```bash
export TF_VAR_phase2_iap_ssh_enabled=true
```

Planifica, revisa y aplica de nuevo. Después:

```bash
gcloud compute ssh "$VM" --zone="$TF_VAR_zone" --project="$TF_VAR_project_id" \
  --tunnel-through-iap --command='id; hostname' \
  --ssh-flag='-oControlMaster=no' --ssh-flag='-oControlPath=none' \
  --ssh-flag='-oConnectTimeout=20' 2>&1 | tee "$EVIDENCE/phase2-ssh-restored.txt"
```

Debe volver a funcionar. No modifiques el firewall manualmente con `gcloud`, para mantener el estado coherente.

## Cerrar la fase

Completa el [resumen de evidencias](../evidence/README.md), sube el resumen revisado y sigue [la limpieza común](README.md#evidencias-github-y-limpieza). Guarda también la confirmación de que la VM y su disco ya no existen.
