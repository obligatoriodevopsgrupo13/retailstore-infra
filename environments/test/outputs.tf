output "vpc_id" {
  description = "ID de la VPC del ambiente test"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las subnets publicas del ambiente test"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas del ambiente test"
  value       = module.networking.private_subnet_ids
}

output "cluster_name" {
  description = "Nombre del cluster ECS del ambiente test"
  value       = module.cluster.cluster_name
}

output "ecr_repository_urls" {
  description = "URLs de repositorios ECR por microservicio en test"
  value = {
    for service_name, repository in module.ecr :
    service_name => repository.repository_url
  }
}

output "alb_dns_names" {
  description = "DNS publicos de los ALBs por microservicio en test"
  value = merge(
    { for service_name, service in module.ecs_service : service_name => service.alb_dns_name },
    {
      "retail-checkout" = module.checkout_service.alb_dns_name
      "retail-ui"       = module.ui_service.alb_dns_name
    }
  )
}

output "rds_endpoint" {
  description = "Endpoint de la instancia RDS PostgreSQL (host:puerto) para conectarse con un cliente SQL"
  value       = module.rds.endpoint
}
