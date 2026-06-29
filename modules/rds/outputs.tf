output "address" {
  description = "Hostname de la instancia RDS (sin puerto)"
  value       = aws_db_instance.this.address
}

output "endpoint" {
  description = "Endpoint completo de la instancia RDS (host:puerto)"
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "Puerto de la instancia RDS"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nombre de la base de datos inicial"
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "ID del Security Group de RDS"
  value       = aws_security_group.rds.id
}
