output "alb_dns_name" {
  description = "DNS publico del Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN del Target Group asociado al servicio"
  value       = aws_lb_target_group.target_group.arn
}

output "service_name" {
  description = "Nombre del ECS Service creado"
  value       = aws_ecs_service.service.name
}

output "task_definition_arn" {
  description = "ARN de la Task Definition registrada"
  value       = aws_ecs_task_definition.task.arn
}

output "ecs_tasks_security_group_id" {
  description = "ID del Security Group aplicado a las tareas ECS"
  value       = aws_security_group.ecs_tasks.id
}
