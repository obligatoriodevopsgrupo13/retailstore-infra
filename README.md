# retailstore-infra

Guía de **despliegue local** del ambiente `dev`

## Prerrequisitos

### Herramientas locales

- Terraform >= 1.7
- AWS CLI configurado
- SAM CLI
- Docker (necesario para el seed de la DB)

### Credenciales AWS

Configurar credenciales con una sesión activa:

```bash
aws configure
```

### Secretos de Terraform

Antes del primer `terraform apply`:

```bash
cd environments/dev
cp secrets.auto.tfvars.example secrets.auto.tfvars
# Editar secrets.auto.tfvars con contraseñas reales
```

En CI/CD, configurar los GitHub Secrets `TF_DB_PASSWORD`, `TF_ADMIN_PASSWORD`, `TF_ADMIN_JWT_SECRET`.

## Despliegue local

### 1. Crear bucket de Terraform state

Crear en S3 el bucket indicado en `environments/dev/terraform.tf` (backend `s3`):

```
obligatorio-devops-tfstate-13
```

Región: `us-east-1`.

### 2. Desplegar infraestructura (Terraform)

```bash
cd environments/dev

cp secrets.auto.tfvars.example secrets.auto.tfvars   # solo la primera vez
# completar secretos en secrets.auto.tfvars

terraform init
terraform plan
terraform apply
```

Infra desplegada por Terraform (dev)

- **Red:** VPC `retail-vpc-dev`, subnets públicas/privadas en 2 AZs.
- **Compute:** cluster ECS Fargate `retail-cluster-dev`.
- **Contenedores:** 6 repos ECR + 6 servicios ECS con ALB (catalog, cart, orders, admin, checkout, ui).
- **Base de datos:** RDS PostgreSQL `retail-db-dev` con DB `orders` y `rds.force_ssl = 0`.
- **Observabilidad:** alarmas CloudWatch (CPU, memoria, 5XX, hosts unhealthy) + dashboard + topic SNS.

Guardar outputs útiles:

```bash
terraform output rds_endpoint
terraform output alb_dns_names
```

### 3. Seed de la base de datos

Prerrequisito: Docker en ejecución o cuaquier cliente de PostrgreSQL (psql).

Obtener el host de RDS:

```bash
terraform output -raw rds_endpoint | cut -d: -f1
```

Copiar el endpoint y ejecutar:

```bash
docker run --rm -it \
  -v "$(pwd -W):/sql" \
  postgres:16 \
  psql -h [RDS_ENDPOINT] -U retail_user -d orders -f //sql/init-db.sql
```

### 4. Push de imágenes Docker a ECR

ECS necesita imágenes en ECR antes de que los servicios queden healthy. Para eso se deben configurar los secrets de AWS en el repositorio RetailStore y correr el pipeline **CI/CD de la app** para build, push a ECR y update de ECS.

### 5. Serverless (monitoreo ECS)

**Prerrequisitos:** paso 1 (bucket S3) y paso 2 (cluster `retail-cluster-dev`).

Una Lambda se ejecuta cada 5 minutos (EventBridge), consulta el cluster ECS y compara `desiredCount` vs `runningCount` de cada microservicio. Si alguno está degradado, publica una alerta en el topic SNS `retail-alerts-dev`.

**Despliegue manual:**

```bash
cd serverless

sam build
sam deploy
```

**Suscribirse a las alertas por email:**

Después del deploy, SAM muestra en los outputs el ARN del SNS topic. Copiar ese ARN y ejecutar:

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:XXXXXXXXXXXX:retail-alerts-dev \
  --protocol email \
  --notification-endpoint <mail>
```

AWS envía un email de confirmación. Hacer clic en **Confirm subscription** para activarlo y recibir las alertas.
