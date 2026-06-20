variable "aws_region" {
  description = "Region de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "vpc_name" {
  description = "Nombre de la VPC del ambiente"
  type        = string
}

variable "vpc_cidr_block" {
  description = "Bloque CIDR principal de la VPC"
  type        = string
}

variable "public_subnets" {
  description = "Bloques CIDR para las subnets publicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "Bloques CIDR para las subnets privadas"
  type        = list(string)
}

variable "availability_zones" {
  description = "Zonas de disponibilidad para las subnets"
  type        = list(string)
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "service_names" {
  description = "Nombres base de los microservicios con repositorio ECR"
  type        = list(string)
  default = [
    "retail-ui",
    "retail-admin",
    "retail-catalog",
    "retail-cart",
    "retail-checkout",
    "retail-orders"
  ]
}
