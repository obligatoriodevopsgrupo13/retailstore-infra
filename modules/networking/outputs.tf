output "vpc_id" {
  description = "ID de la VPC creada por el modulo networking"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Bloque CIDR asignado a la VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets publicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway asociado a la VPC"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway usado por las subnets privadas"
  value       = aws_nat_gateway.this.id
}
