# Trabajo con Terraform

- Revisa el resultado de `terraform plan` antes de ejecutar cualquier `terraform apply`.
- En la fase de preparación, ejecuta únicamente comprobaciones, `init`, `validate` y `plan`; no despliegues recursos.
- Antes de un despliegue posterior, revisa permisos IAM, exposición de red y posibles costes. Si se guarda un plan, revisa ese mismo archivo y aplícalo únicamente cuando el despliegue forme parte del trabajo solicitado.
