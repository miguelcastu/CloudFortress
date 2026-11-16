# Preparación de Terraform en Google Cloud Shell

Ejecuta estos pasos en la terminal Bash de Google Cloud Shell. Esta fase comprueba la instalación, inicializa el directorio y genera un plan para revisarlo. No despliega recursos. Para los laboratorios 2, 3 y 4, continúa después con [la guía de fases](phases/README.md).

## 1. Comprobar la instalación

Comprueba qué comando se está ejecutando:

```bash
type -a terraform
terraform version
```

Si aparece un mensaje de instalación en lugar de la versión, actualiza la terminal:

```bash
hash -r
bash
terraform version
```

`hash -r` limpia las rutas almacenadas por Bash. `bash` abre una nueva instancia; los siguientes comandos se ejecutan en esa nueva terminal.

Si instalaste el binario en `/usr/bin/terraform`, compruébalo directamente:

```bash
/usr/bin/terraform version
```

Si funciona, puedes priorizar el directorio en la sesión:

```bash
export PATH="/usr/bin:$PATH"
hash -r
type -a terraform
terraform version
```

Cambiar el `PATH` no elimina alias ni funciones. Si alguno sigue interceptando `terraform`, utiliza directamente `/usr/bin/terraform` en los siguientes pasos. Si ese archivo no existe, utiliza la ruta del binario instalado que identifiques con `type -a terraform`; no basta con modificar el `PATH` para instalarlo.

## 2. Seleccionar el proyecto y las credenciales

Comprueba primero el proyecto activo de Google Cloud:

```bash
gcloud config get-value project
```

Si no hay ninguno configurado, selecciona el proyecto del laboratorio:

```bash
gcloud config set project TU_PROJECT_ID
```

Cloud Shell utiliza las credenciales de la sesión de Google Cloud y no necesita ejecutar `gcloud auth application-default login`. Si solicita autorizar el acceso de la terminal a tu cuenta, completa ese paso. Consulta la [documentación de autenticación de Google Cloud](https://docs.cloud.google.com/docs/terraform/authentication).

Desde Bash, exporta el proyecto y comprueba que no esté vacío ni sea `(unset)`:

```bash
export TF_VAR_project_id="$(gcloud config get-value project)"
printf 'Proyecto para Terraform: %s\n' "$TF_VAR_project_id"
```

No continúes con el plan si el comando de Google Cloud ha fallado o no devuelve el ID correcto.

## 3. Inicializar y validar CloudFortress

Si todavía no tienes el repositorio en Cloud Shell, clónalo una sola vez:

```bash
git clone https://github.com/miguelcastu/CloudFortress.git ~/CloudFortress
```

Si ya está clonado, utiliza esa copia. Con el repositorio en `~/CloudFortress` y el binario en `/usr/bin/terraform`:

```bash
cd ~/CloudFortress/infra/terraform
/usr/bin/terraform init
/usr/bin/terraform fmt -check
/usr/bin/terraform validate
```

Adapta la ruta del repositorio a tu clon y la del ejecutable a tu instalación. Desde la raíz del repositorio también puedes acceder con `cd infra/terraform`.

[`terraform init`](https://developer.hashicorp.com/terraform/cli/commands/init) prepara el directorio e instala las dependencias. En esta configuración utiliza el backend local y descarga el proveedor de Google Cloud; no crea la VPC, la subred ni el servicio Cloud Run.

Ejecuta cada comando por separado y detente si aparece un error. Una validación correcta muestra `Success! The configuration is valid.`

Conserva `.terraform.lock.hcl` en Git. El directorio `.terraform/`, los estados y los planes quedan excluidos.

## 4. Generar y revisar el plan

```bash
/usr/bin/terraform plan -out=tfplan
/usr/bin/terraform show -no-color tfplan
```

[`terraform plan`](https://developer.hashicorp.com/terraform/cli/commands/plan) calcula los cambios propuestos sin ejecutarlos. Requiere un proyecto válido y credenciales; una validación correcta no confirma por sí sola los permisos de despliegue.

Antes de continuar, revisa:

- Recursos que se crearían, modificarían o eliminarían y el proyecto y la región de destino.
- Identidades y permisos IAM, especialmente cualquier acceso público o permiso excesivo.
- Exposición a Internet: Cloud Run admite ingreso desde Internet, aunque requiere autorización IAM en esta configuración.
- Posibles costes, límites de escalado y protección contra borrado.

**Regla del laboratorio: nunca ejecutar `terraform apply` sin revisar antes el plan.** Esta fase termina con la revisión; el despliegue se trata en un paso posterior. Si cambia la configuración, las variables o el estado, genera y revisa un nuevo plan. No subas el plan a Git: puede contener datos sensibles.
