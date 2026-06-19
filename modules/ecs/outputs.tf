output "cluster_id" {
  description = "ID del cluster ECS creado"
  value       = aws_ecs_cluster.ecs-cluster.id
}

output "cluster_arn" {
  description = "ARN del cluster ECS creado"
  value       = aws_ecs_cluster.ecs-cluster.arn
}

output "cluster_name" {
  description = "Nombre del cluster ECS creado"
  value       = aws_ecs_cluster.ecs-cluster.name
}
