# Fase 4: identidades y mínimo privilegio

Archivo: [`phase4_iam.tf`](../../infra/terraform/phase4_iam.tf). Completa la limpieza de la fase anterior y la [preparación común](README.md).

## Seleccionar y desplegar

```bash
export TF_VAR_lab_phase=4
export TF_VAR_phase4_allow_read=true
export TF_VAR_bucket_name_suffix=lab
```

Genera, revisa y aplica el plan con el procedimiento común. Se crean dos buckets con acceso uniforme y prevención de acceso público, un objeto `health.txt` en cada uno, una cuenta de servicio dedicada y un Job.

Solo el bucket `allowed` tiene un binding `roles/storage.objectViewer` para la cuenta del Job. No se concede ese rol a nivel de proyecto ni al bucket `restricted`. Los permisos del operador de Terraform no se trasladan al contenedor: el Job obtiene un token temporal del servicio de metadatos con su propia identidad, sin archivos de claves.

Los nombres son `PROJECT_ID-cf-allowed-SUFFIX` y `PROJECT_ID-cf-restricted-SUFFIX`. Si alguno ya pertenece a otro propietario, cambia `bucket_name_suffix` antes del despliegue y conserva ese valor durante todas las pruebas y la limpieza. La política de borrado lógico del laboratorio se desactiva y `force_destroy=false` protege objetos inesperados; utiliza únicamente datos de prueba.

## Prueba positiva y acceso denegado

```bash
export JOB=cloudfortress-storage-probe
export STAGE=phase4-allowed
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Captura los detalles y logs con [el bloque común](README.md#guardar-logs-de-un-job). Resultados esperados:

| Objeto consultado | HTTP esperado | Significado |
| --- | --- | --- |
| `allowed/health.txt` | 200 | Lectura autorizada |
| `restricted/health.txt` | 403 | Lectura denegada |

El Job termina correctamente solo si ambos resultados coinciden. HTTP 404 no sustituye a HTTP 403 como evidencia. Un HTTP 401, un error de red o un Job que no llega a arrancar tampoco demuestra una denegación IAM.

## Retirar y restaurar el permiso

```bash
export TF_VAR_phase4_allow_read=false
```

Genera y revisa el plan: debe eliminar únicamente el binding `allowed_reader` y actualizar la expectativa del Job a HTTP 403 para el bucket antes autorizado. Aplícalo después de revisarlo. Después:

```bash
export STAGE=phase4-revoked
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Guarda sus logs: **ambos** objetos deben devolver HTTP 403. El Job termina correctamente porque esa es ahora la expectativa de la prueba.

Los cambios de IAM no son instantáneos. Si aún aparece el resultado anterior, espera varios minutos y repite la ejecución, conservando ambos resultados; no concedas permisos adicionales. Consulta [propagación de cambios IAM](https://docs.cloud.google.com/iam/docs/access-change-propagation).

```bash
export TF_VAR_phase4_allow_read=true
```

Genera, revisa y aplica el plan de restauración. Después:

```bash
export STAGE=phase4-restored
gcloud run jobs execute "$JOB" --project="$TF_VAR_project_id" \
  --region="$TF_VAR_region" --wait 2>&1 | tee "$EVIDENCE/$STAGE-run.txt"
```

Guarda sus logs: vuelve a esperar 200 en `allowed` y 403 en `restricted`.

Si el bucket restringido devuelve 200, la prueba falla deliberadamente. Revisa posibles permisos heredados de proyecto, carpeta u organización; un binding a nivel de bucket no anula otras concesiones. No pruebes con el token del operador ni concedas `Owner`, `Editor` o `Storage Admin` a la cuenta del Job.

## Cerrar la fase

Documenta los códigos HTTP de cada bucket antes, durante y después de retirar el rol. Revisa y sube el resumen, luego realiza [la limpieza común](README.md#evidencias-github-y-limpieza). Terraform elimina los objetos de prueba antes que los buckets; no uses buckets que contengan información real.
