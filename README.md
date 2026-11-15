# CloudFortress

Infraestructura de laboratorio en Google Cloud gestionada con Terraform.

## Estructura

```text
CloudFortress/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   └── architecture/
│       └── README.md
└── infra/
    └── terraform/
        ├── .terraform.lock.hcl
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Recursos

- VPC personalizada `cloudfortress-vpc`.
- Subred `cloudfortress-subnet` con rango `10.10.10.0/24` y Private Google Access.
- Cuenta de servicio `cloudfortress-app` para la aplicación.
- Servicio Cloud Run `cloudfortress-hello` con una imagen de ejemplo, autenticación IAM y escalado entre cero y una instancia.

El servicio permite tráfico de entrada desde Internet, pero no concede invocación anónima. La configuración actual no conecta Cloud Run a la VPC. Consulta [la arquitectura](docs/architecture/README.md) para más detalles.

## Requisitos

- Terraform >= 1.7.0.
- Google Cloud CLI y credenciales con permisos para crear los recursos definidos.
- Un proyecto de Google Cloud con facturación y las APIs de Compute Engine, Cloud Run e IAM habilitadas.

## Uso

Autentica las credenciales locales de la aplicación:

```sh
gcloud auth application-default login
```

Desde la raíz del repositorio:

```sh
cd infra/terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -var="project_id=TU_PROJECT_ID" -out=tfplan
terraform apply tfplan
```

`project_id` es obligatorio. `region` utiliza `europe-west1` por defecto y se puede cambiar añadiendo `-var="region=TU_REGION"` al comando `terraform plan`.

Las salidas incluyen los nombres de la VPC y la subred, la URL de Cloud Run y la cuenta de servicio de la aplicación. El despliegue puede generar costes en Google Cloud.

Para eliminar los recursos creados:

```sh
terraform destroy -var="project_id=TU_PROJECT_ID"
```

Si cambiaste la región, utiliza también ese mismo valor al eliminar los recursos.

## Estado y credenciales

El estado de Terraform se guarda localmente; configura un backend remoto antes de trabajar en equipo. `.gitignore` excluye estados, planes, archivos de variables y credenciales locales. El archivo `.terraform.lock.hcl` debe versionarse cuando se genere con `terraform init`.

## Licencia

[MIT](LICENSE).
