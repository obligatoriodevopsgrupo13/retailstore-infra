data "aws_iam_role" "labrole" {
  name = "LabRole"
}

module "networking" {
  source             = "../../modules/networking"
  vpc_name           = var.vpc_name
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  environment        = var.environment
}

module "cluster" {
  source       = "../../modules/ecs"
  cluster_name = var.cluster_name
  environment  = var.environment
}

module "ecr" {
  for_each = toset(var.service_names)

  source      = "../../modules/ecr"
  name        = "${each.key}-${var.environment}"
  environment = var.environment
}

module "rds" {
  source = "../../modules/rds"

  name        = "retail-db-${var.environment}"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr_block
  subnet_ids  = module.networking.public_subnet_ids
  db_name     = "orders"
  username    = var.db_username
  password    = var.db_password
}

locals {
  db_host = module.rds.address

  core_services = toset([
    "retail-catalog",
    "retail-cart",
    "retail-orders",
    "retail-admin",
  ])

  core_env_vars = {
    "retail-catalog" = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "${local.db_host}:5432" },
      { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
      { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = var.db_username },
      { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    "retail-cart" = [
      { name = "CART_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "CART_POSTGRES_HOST", value = local.db_host },
      { name = "CART_POSTGRES_PORT", value = "5432" },
      { name = "CART_POSTGRES_DB", value = "cartdb" },
      { name = "CART_POSTGRES_USER", value = var.db_username },
      { name = "CART_POSTGRES_PASSWORD", value = var.db_password },
      { name = "PORT", value = "8080" },
    ]
    "retail-orders" = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = "${local.db_host}:5432" },
      { name = "RETAIL_ORDERS_PERSISTENCE_NAME", value = "orders" },
      { name = "RETAIL_ORDERS_PERSISTENCE_USERNAME", value = var.db_username },
      { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password },
    ]
    "retail-admin" = [
      { name = "DB_HOST", value = local.db_host },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "ADMIN_USERNAME", value = var.admin_username },
      { name = "ADMIN_PASSWORD", value = var.admin_password },
      { name = "ADMIN_JWT_SECRET", value = var.admin_jwt_secret },
    ]
  }
}

module "ecs_service" {
  for_each = local.core_services

  source                = "../../modules/ecs_service"
  app_name              = "${each.key}-${var.environment}"
  environment           = var.environment
  cluster_id            = module.cluster.cluster_id
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  image_url             = module.ecr[each.key].repository_url
  image_tag             = var.image_tag
  execution_role_arn    = data.aws_iam_role.labrole.arn
  environment_variables = local.core_env_vars[each.key]
}

module "checkout_service" {
  source             = "../../modules/ecs_service"
  app_name           = "retail-checkout-${var.environment}"
  environment        = var.environment
  cluster_id         = module.cluster.cluster_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  image_url          = module.ecr["retail-checkout"].repository_url
  image_tag          = var.image_tag
  execution_role_arn = data.aws_iam_role.labrole.arn

  environment_variables = [
    { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "in-memory" },
    { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://${module.ecs_service["retail-orders"].alb_dns_name}" },
  ]
}

module "ui_service" {
  source             = "../../modules/ecs_service"
  app_name           = "retail-ui-${var.environment}"
  environment        = var.environment
  cluster_id         = module.cluster.cluster_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  image_url          = module.ecr["retail-ui"].repository_url
  image_tag          = var.image_tag
  execution_role_arn = data.aws_iam_role.labrole.arn

  environment_variables = [
    { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://${module.ecs_service["retail-catalog"].alb_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://${module.ecs_service["retail-cart"].alb_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://${module.checkout_service.alb_dns_name}" },
    { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://${module.ecs_service["retail-orders"].alb_dns_name}" },
  ]
}

module "observability" {
  source = "../../modules/observability"

  app_name     = "retailstore"
  environment  = var.environment
  aws_region   = var.aws_region
  cluster_name = var.cluster_name

  alarm_email = var.alarm_email

  cpu_threshold             = var.obs_cpu_threshold
  memory_threshold          = var.obs_memory_threshold
  error_5xx_threshold       = var.obs_error_5xx_threshold
  response_time_threshold   = var.obs_response_time_threshold
  unhealthy_hosts_threshold = var.obs_unhealthy_hosts_threshold

  critical_services = ["retail-checkout", "retail-orders", "retail-cart"]

  services = merge(
    {
      for name, svc in module.ecs_service : name => {
        alb_arn          = svc.alb_arn
        target_group_arn = svc.target_group_arn
        service_name     = svc.service_name
      }
    },
    {
      "retail-checkout" = {
        alb_arn          = module.checkout_service.alb_arn
        target_group_arn = module.checkout_service.target_group_arn
        service_name     = module.checkout_service.service_name
      }
      "retail-ui" = {
        alb_arn          = module.ui_service.alb_arn
        target_group_arn = module.ui_service.target_group_arn
        service_name     = module.ui_service.service_name
      }
    }
  )
}
