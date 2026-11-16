# CloudFortress

Infraestructura de laboratorio en Google Cloud gestionada con Terraform.

## Estructura

```text
CloudFortress/
├── AGENTS.md
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── getting-started.md
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

Sigue la [guía de preparación en Google Cloud Shell](docs/getting-started.md) para comprobar la instalación, actualizar Bash si es necesario, configurar el proyecto y resolver alias o funciones que intercepten Terraform. En Cloud Shell no hace falta crear credenciales locales; en un equipo local, autentica Application Default Credentials:

```sh
gcloud auth application-default login
```

Con el proyecto de Google Cloud ya configurado, desde la raíz del repositorio y en Bash:

```bash
export TF_VAR_project_id="$(gcloud config get-value project)"
printf 'Proyecto para Terraform: %s\n' "$TF_VAR_project_id"
cd infra/terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show -no-color tfplan
```

Ejecuta los comandos en orden y detente si alguno falla. Comprueba que `TF_VAR_project_id` contenga el ID correcto antes de generar el plan. Si necesitas evitar un alias o función en Linux, utiliza `/usr/bin/terraform` cuando esa sea la ruta del binario instalado.

**Nunca ejecutes `terraform apply` sin revisar primero el plan.** Revisa permisos IAM, exposición a Internet, recursos propuestos y posibles costes. Esta fase termina con el plan y no despliega recursos.

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
