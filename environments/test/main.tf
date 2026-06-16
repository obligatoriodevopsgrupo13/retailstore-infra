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
