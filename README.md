# Guía de deploy - RetailStore

Documentación para desplegar el sistema.

- **CI/CD (recomendado):** pasos 1–7 más abajo — infra por pipeline, imágenes desde RetailStore.
- **Local:** ver sección [Despliegue local](#despliegue-local) — Terraform y SAM desde tu máquina.

En ambos casos, el bucket S3, el seed de BD y el push de imágenes requieren pasos manuales o pipeline del repo app.

---

## Resumen del flujo (CI/CD)

```
1. Bucket S3 (state)     → manual
2. Secrets en GitHub     → manual
3. Infra (Terraform)     → pipeline infra.yaml
4. Seed PostgreSQL       → manual, una vez por ambiente
5. Imágenes → ECR        → pipeline CI/CD repo RetailStore
6. Lambda monitoreo      → pipeline serverless.yaml (+ suscripción a alertas)
7. Observabilidad        → pipeline infra.yaml
```

Región: **us-east-1**

---

## Paso 1 — Crear bucket S3 (manual, una vez)

Antes del primer deploy, crear en AWS:

```
obligatorio-devops-tfstate-13
```

- Región: `us-east-1`
- Recomendado: activar **versionado** (útil para rollback del state)

Este bucket guarda:

- State de Terraform: `dev/terraform.tfstate`, `test/terraform.tfstate`, `prod/terraform.tfstate`
- Artefactos SAM: prefijo `sam/`

---

## Paso 2 — Secrets en GitHub (manual, una vez)

### Repo `retailstore-infra`

**Settings → Secrets and variables → Actions → Repository secrets**

#### AWS (labs / credenciales temporales)


| Secret                  | Uso                                     |
| ----------------------- | --------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | Deploy Terraform + SAM                  |
| `AWS_SECRET_ACCESS_KEY` | Idem                                    |
| `AWS_SESSION_TOKEN`     | Obligatorio en labs con sesión temporal |


#### Terraform (dev, test y prod usan los mismos secrets)


| Secret en GitHub      | Variable que recibe Terraform |
| --------------------- | ----------------------------- |
| `TF_DB_PASSWORD`      | `TF_VAR_db_password`          |
| `TF_ADMIN_PASSWORD`   | `TF_VAR_admin_password`       |
| `TF_ADMIN_JWT_SECRET` | `TF_VAR_admin_jwt_secret`     |


`TF_DB_PASSWORD` debe tener **8–128 caracteres** y **no** contener `/`, `@`, `"` ni espacios (requisito de RDS). Ejemplo: `RetailDb1!`

#### Quality gates


| Secret        | Uso                                |
| ------------- | ---------------------------------- |
| `SONAR_TOKEN` | Workflow `quality-gates-infra.yml` |


---

## Paso 3 — Desplegar infraestructura (pipeline)

**Workflow:** `Infrastructure CI/CD` (`infra.yaml`)

### Cómo dispararlo

**Opción A — Push automático**

```bash
git push origin develop   # → environments/dev
git push origin main      # → environments/prod
```

Solo corre si hay cambios en `environments/**`, `modules/**` o el workflow.

**Opción B — Manual**

GitHub → **Actions → Infrastructure CI/CD → Run workflow**

Elegir ambiente: `dev`, `test` o `prod`.

### Qué hace el pipeline

1. TruffleHog (secret scan)
2. `terraform init` → `validate` → `fmt -check` → `plan` → `apply`
3. En **pull requests** solo hace plan (no apply)

### Qué queda desplegado (ejemplo dev)

- VPC `retail-vpc-dev` + subnets en 2 AZs
- Cluster ECS `retail-cluster-dev`
- 6 repos ECR + 6 servicios ECS con ALB
- RDS PostgreSQL `retail-db-dev` (base `orders`)
- CloudWatch: alarmas, dashboard, SNS

Recursos por ambiente:


| Ambiente | VPC               | Cluster ECS           | RDS              |
| -------- | ----------------- | --------------------- | ---------------- |
| `dev`    | `retail-vpc-dev`  | `retail-cluster-dev`  | `retail-db-dev`  |
| `test`   | `retail-vpc-test` | `retail-cluster-test` | `retail-db-test` |
| `prod`   | `retail-vpc-prod` | `retail-cluster-prod` | `retail-db-prod` |


### Obtener outputs (sin Terraform local)

Reemplazar `<env>` por `dev`, `test` o `prod`:

```bash
# Host RDS
aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='retail-db-<env>'].Endpoint.Address" \
  --output text

# DNS del ALB de la UI
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'retail-ui-<env>')].DNSName" \
  --output text
```

También podés usar `terraform output` localmente si tenés credenciales y acceso al state en S3.

---

## Paso 4 — Seed de la base de datos (manual, una vez)

RDS crea la base `orders` al provisionarse. Hay que ejecutar `environments/<env>/init-db.sql` para crear `catalogdb`, `cartdb`, permisos y la tabla `cart_items`.

**Prerrequisitos:** Docker o `psql`, credenciales AWS activas, password configurada en `TF_DB_PASSWORD`.

```bash
# Ejemplo para dev (cambiar env según corresponda)
ENV=dev

RDS_HOST=$(aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='retail-db-${ENV}'].Endpoint.Address" \
  --output text)

docker run --rm -it \
  -v "$(pwd)/environments/${ENV}:/sql" \
  postgres:16 \
  psql -h "$RDS_HOST" -U retail_user -d orders -f /sql/init-db.sql
```

**Windows (PowerShell):**

```powershell
docker run --rm -it `
  -v "C:\ruta\al\repo\environments\dev:/sql" `
  postgres:16 `
  psql -h <RDS_HOST> -U retail_user -d orders -f /sql/init-db.sql
```

> Este paso no lo hace ningún pipeline. Repetir solo si se recrea RDS desde cero.

---

## Paso 5 — Push de imágenes a ECR (repo RetailStore)

ECS necesita imágenes en ECR antes de quedar healthy. Eso lo hace el **pipeline CI/CD del repo RetailStore** (repo separado de la app).

### Setup en RetailStore (una vez)

**Settings → Secrets and variables → Actions:**


| Secret                  | Uso                       |
| ----------------------- | ------------------------- |
| `AWS_ACCESS_KEY_ID`     | Login ECR + push imágenes |
| `AWS_SECRET_ACCESS_KEY` | Idem                      |
| `AWS_SESSION_TOKEN`     | Idem (labs temporales)    |


(Ajustar nombres si el workflow de RetailStore usa otros.)

### Disparar deploy de la app

```bash
# En el repo RetailStore
git push origin develop   # dev
git push origin main      # prod
```

El pipeline debería:

1. Buildear las 6 imágenes (ui, catalog, cart, orders, checkout, admin)
2. Pushearlas a los repos ECR del ambiente (`retail-*-dev`, `retail-*-prod`, etc.)
3. Actualizar los servicios ECS en el cluster correspondiente

### Verificar servicios ECS

```bash
# Ejemplo dev
aws ecs describe-services \
  --cluster retail-cluster-dev \
  --services retail-ui-dev retail-catalog-dev retail-cart-dev \
             retail-orders-dev retail-checkout-dev retail-admin-dev \
  --query "services[].{name:serviceName,running:runningCount,desired:desiredCount}" \
  --output table
```

Cuando `running == desired` en todos, la tienda responde en el DNS del ALB de `retail-ui-<env>`.

---

## Paso 6 — Monitoreo serverless (pipeline, automático)

**Workflow:** `Serverless CI/CD` (`serverless.yaml`)

Se dispara al pushear cambios en `serverless/` a `develop` o `main`.

Despliega la Lambda `ecs-health-monitor`, que revisa el cluster cada 5 minutos y publica alertas en SNS (`retail-alerts-dev` / `retail-alerts-prod`).

**Suscripción por email (opcional):**

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:<ACCOUNT_ID>:retail-alerts-dev \
  --protocol email \
  --notification-endpoint <tu-email>
```

Confirmar la suscripción desde el mail que envía AWS.

---

## Workflows de `retailstore-infra`


| Workflow                  | Cuándo corre                      | Qué hace                            |
| ------------------------- | --------------------------------- | ----------------------------------- |
| `infra.yaml`              | push `develop`/`main`, PR, manual | Terraform plan/apply                |
| `quality-gates-infra.yml` | push, PR                          | Sonar, fmt, validate, TFLint, Trivy |
| `serverless.yaml`         | push `serverless/`                | SAM build + deploy Lambda           |


---

## Rollback rápido


| Qué falló         | Acción                                                                    |
| ----------------- | ------------------------------------------------------------------------- |
| Infra (Terraform) | `git revert` del commit + push → el pipeline reaplica la versión anterior |
| App (código)      | Rollback en repo RetailStore o task definition anterior en ECS            |
| Datos RDS         | Restore desde snapshot (no hay rollback automático de datos)              |


---

## Despliegue local

Alternativa al pipeline de CI/CD: ejecutar Terraform, seed y SAM desde tu máquina. Los pasos de imágenes en ECR siguen yendo por el pipeline del repo **RetailStore**.

### Prerrequisitos

- Terraform >= 1.7
- AWS CLI configurado (`aws configure`)
- SAM CLI
- Docker (seed de la base de datos)

### 1. Crear bucket de Terraform state

Igual que en el [Paso 1](#paso-1--crear-bucket-s3-manual-una-vez): bucket `obligatorio-devops-tfstate-13` en `us-east-1`.

### 2. Secretos locales

```bash
cd environments/dev
cp secrets.auto.tfvars.example secrets.auto.tfvars
# Editar secrets.auto.tfvars con contraseñas reales
```


| Variable           | Descripción                                                              |
| ------------------ | ------------------------------------------------------------------------ |
| `db_password`      | Password RDS (`retail_user`). 8–128 chars, sin `/`, `@`, `"` ni espacios |
| `admin_password`   | Password del panel admin                                                 |
| `admin_jwt_secret` | Secreto JWT del servicio admin                                           |


Para `test` o `prod`, repetir en `environments/<env>/` con su `secrets.auto.tfvars.example`.

### 3. Desplegar infraestructura (Terraform)

```bash
cd environments/dev

terraform init
terraform plan
terraform apply
```

Infra desplegada (dev):

- **Red:** VPC `retail-vpc-dev`, subnets públicas/privadas en 2 AZs
- **Compute:** cluster ECS Fargate `retail-cluster-dev`
- **Contenedores:** 6 repos ECR + 6 servicios ECS con ALB (catalog, cart, orders, admin, checkout, ui)
- **Base de datos:** RDS PostgreSQL `retail-db-dev` con DB `orders`
- **Observabilidad:** alarmas CloudWatch + dashboard + topic SNS

Outputs útiles:

```bash
terraform output rds_endpoint
terraform output alb_dns_names
```

### 4. Seed de la base de datos

Prerrequisito: Docker en ejecución o cliente PostgreSQL (`psql`).

Obtener el host de RDS:

```bash
cd environments/dev
terraform output -raw rds_endpoint | cut -d: -f1
```

Ejecutar el script de inicialización:

```bash
# Git Bash / Linux / macOS (desde environments/dev)
docker run --rm -it \
  -v "$(pwd):/sql" \
  postgres:16 \
  psql -h <RDS_HOST> -U retail_user -d orders -f /sql/init-db.sql
```

**Windows (PowerShell):**

```powershell
docker run --rm -it `
  -v "${PWD}:/sql" `
  postgres:16 `
  psql -h <RDS_HOST> -U retail_user -d orders -f /sql/init-db.sql
```

### 5. Push de imágenes Docker a ECR

Igual que el [Paso 5](#paso-5--push-de-imágenes-a-ecr-repo-retailstore): configurar secrets AWS en **RetailStore** y correr su pipeline CI/CD (build, push a ECR, update ECS).

### 6. Serverless (monitoreo ECS)

**Prerrequisitos:** bucket S3 y cluster `retail-cluster-dev` ya desplegados.

Lambda que revisa el cluster cada 5 minutos y alerta por SNS si un servicio está degradado.

```bash
cd serverless

sam build
sam deploy
```

**Suscribirse a alertas por email** (ARN del topic en los outputs de SAM):

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:<ACCOUNT_ID>:retail-alerts-dev \
  --protocol email \
  --notification-endpoint <tu-email>
```

Confirmar la suscripción desde el mail de AWS.