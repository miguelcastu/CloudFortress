# CloudFortress

Laboratorio de arquitectura de seguridad en Google Cloud gestionado con Terraform: acceso administrativo privado, comunicación entre aplicaciones y autorización de recursos.

| Fase | Qué construye | Qué demuestra |
| --- | --- | --- |
| 1: base | VPC, subred privada, identidad y servicio Cloud Run autenticado | Infraestructura inicial |
| 2: acceso seguro | VM Debian sin IP pública, IAP, OS Login y firewall SSH | Conexión permitida, bloqueada y restaurada |
| 3: conectividad privada | Job con Direct VPC egress y VM HTTP privada | HTTP 200 y bloqueo entre subredes |
| 4: mínimo privilegio | Dos buckets privados e identidad de aplicación | Lectura 200/403, retirada y restauración del rol |

## Ejecutar el laboratorio

Los comandos de Google Cloud se ejecutan en Cloud Shell. Empieza por la [comprobación de instalación](docs/getting-started.md) y sigue las [instrucciones comunes de las fases](docs/phases/README.md), que incluyen despliegue, captura de logs, evidencias y destrucción.

- [Fase 2: acceso seguro](docs/phases/phase2.md).
- [Fase 3: conectividad privada](docs/phases/phase3.md).
- [Fase 4: IAM y mínimo privilegio](docs/phases/phase4.md).
- [Arquitectura y diagramas](docs/architecture/README.md).
- [Plantilla de evidencias](docs/evidence/README.md).

**Nunca ejecutes `terraform apply` sin revisar antes el plan.** El repositorio no despliega recursos ni ejecuta pruebas en Google Cloud automáticamente. Los resultados esperados están separados de las evidencias que registres al ejecutar el laboratorio.

## Requisitos y variables

Terraform >= 1.7.0, Google Cloud CLI, un proyecto con facturación y permisos de despliegue adecuados. La guía común explica las APIs y las identidades. En Cloud Shell se utiliza la autenticación de la sesión; para Terraform en un equipo local, configura Application Default Credentials.

| Variable | Valor por defecto | Uso |
| --- | --- | --- |
| `project_id` | Obligatoria | ID del proyecto del laboratorio |
| `lab_phase` | `1` | Activa una fase a la vez: 1, 2, 3 o 4 |
| `region` | `europe-west1` | Región de los recursos |
| `zone` | Región + `-b` | Zona de las VMs, dentro de la región |
| `operator_member` | `null` | Obligatoria en fase 2: `user:EMAIL` o `group:EMAIL` |
| `phase2_iap_ssh_enabled` | `true` | Control reversible de SSH |
| `phase3_http_enabled` | `true` | Control reversible del firewall HTTP |
| `phase4_allow_read` | `true` | Control reversible del permiso de lectura |
| `bucket_name_suffix` | `lab` | Resuelve conflictos globales de nombres de buckets |
| `vm_machine_type` | `e2-micro` | Tipo de VM de laboratorio |
| `debian_image` | `debian-cloud/debian-12` | Imagen; fase 3 requiere Python 3 preinstalado |
| `python_container_image` | `docker.io/library/python:3.12-slim` | Runtime de los Jobs; permite fijar un digest |

No necesitas escribir IDs en el código: proporciona el proyecto y el operador como variables siguiendo las guías. Cambiar de fase puede eliminar sus recursos; completa las pruebas y la limpieza antes de pasar a la siguiente.

## Estructura

```text
CloudFortress/
├── AGENTS.md
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
├── docs/
│   ├── getting-started.md
│   ├── architecture/README.md
│   ├── evidence/README.md
│   └── phases/
│       ├── README.md
│       ├── phase2.md
│       ├── phase3.md
│       └── phase4.md
├── infra/terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── network_lab.tf
│   ├── phase3_private_connectivity.tf
│   ├── phase4_iam.tf
│   ├── scripts/
│   ├── templates/
│   └── tests/security.tftest.hcl
└── tests/test_probes.py
```

## Estado, costes y limpieza

El estado de Terraform se guarda localmente. Consérvalo durante todo el laboratorio y configura un backend remoto antes de trabajar en equipo. `.gitignore` excluye estados, planes, variables locales, credenciales, cachés y evidencias originales. Versiona `.terraform.lock.hcl`.

Las VMs y discos, los Jobs, el almacenamiento y los logs pueden generar costes. El servicio Cloud Run original escala a cero cuando no se usa. La [limpieza común](docs/phases/README.md#evidencias-github-y-limpieza) utiliza un plan de destrucción revisado, elimina los recursos del laboratorio y conserva las APIs habilitadas. Los buckets contienen solo objetos de prueba; no se fuerzan borrados de datos inesperados.

## Comprobar el código sin desplegar

Con las dependencias de Terraform inicializadas:

```bash
terraform -chdir=infra/terraform fmt -check -recursive
terraform -chdir=infra/terraform validate
terraform -chdir=infra/terraform test
python3 -m unittest discover -s tests -v
```

Los tests de Terraform simulan el proveedor y solo calculan planes; las pruebas Python usan un servidor local y respuestas simuladas. Las pruebas reales se realizan por separado en Cloud Shell.

## Licencia

[MIT](LICENSE).
