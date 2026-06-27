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

module "ecs_service" {
  for_each = toset(var.service_names)

  source             = "../../modules/ecs_service"
  app_name           = "${each.key}-${var.environment}"
  environment        = var.environment
  cluster_id         = module.cluster.cluster_id
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  image_url          = module.ecr[each.key].repository_url
  image_tag          = var.image_tag
  execution_role_arn = data.aws_iam_role.labrole.arn
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

  services = {
    for name in var.service_names : name => {
      alb_arn          = module.ecs_service[name].alb_arn
      target_group_arn = module.ecs_service[name].target_group_arn
      service_name     = module.ecs_service[name].service_name
    }
  }
}