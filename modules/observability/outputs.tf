output "sns_topic_arn" {
  description = "ARN del topic SNS para notificaciones de alarmas"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL directa al dashboard en la consola de AWS"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cpu_alarm_arns" {
  description = "ARNs de las alarmas de CPU (servicios críticos)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecs_cpu_high : k => v.arn }
}

output "memory_alarm_arns" {
  description = "ARNs de las alarmas de memoria (servicios críticos)"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecs_memory_high : k => v.arn }
}
