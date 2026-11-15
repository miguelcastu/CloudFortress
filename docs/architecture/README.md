# Arquitectura

CloudFortress define un laboratorio de Google Cloud en `infra/terraform`.

## Red

La VPC `cloudfortress-vpc` desactiva la creación automática de subredes. La subred regional `cloudfortress-subnet` usa `10.10.10.0/24` y habilita Private Google Access.

## Aplicación e identidad

El servicio Cloud Run `cloudfortress-hello` ejecuta la imagen de ejemplo `us-docker.pkg.dev/cloudrun/container/hello` con la cuenta de servicio dedicada `cloudfortress-app`.

El ingreso se configura como `INGRESS_TRAFFIC_ALL`. No se concede el rol de invocador a `allUsers`, por lo que la aplicación requiere autenticación y autorización IAM. La cuenta de ejecución no recibe roles adicionales en esta configuración.

Cloud Run escala entre cero y una instancia. La protección contra borrado está desactivada para permitir eliminar el laboratorio con Terraform.

## Alcance actual

- Cloud Run no tiene configurada una conexión de salida a la VPC.
- No se crean balanceadores, Cloud NAT, reglas de firewall adicionales ni bases de datos.
- Las APIs y la facturación del proyecto deben estar habilitadas previamente.
- El estado utiliza el backend local predeterminado de Terraform.

## Parámetros y salidas

| Variable | Uso | Valor predeterminado |
| --- | --- | --- |
| `project_id` | Proyecto de Google Cloud | Obligatorio |
| `region` | Región de la subred y Cloud Run | `europe-west1` |

Las salidas son `vpc_name`, `subnet_name`, `service_url` y `service_account`. La URL publicada como salida sigue requiriendo permisos de invocación.
