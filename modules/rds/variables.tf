variable "name" {
  description = "Nombre/identificador de la instancia RDS"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue, por ejemplo dev, test o prod"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crea el Security Group de RDS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC, usado para permitir acceso interno desde las tasks ECS"
  type        = string
}

variable "subnet_ids" {
  description = "IDs de subnets para el DB subnet group (publicas, para poder conectarse con un cliente SQL)"
  type        = list(string)
}

variable "db_name" {
  description = "Nombre de la base de datos inicial creada por RDS"
  type        = string
  default     = "orders"
}

variable "username" {
  description = "Usuario maestro de la base de datos"
  type        = string
}

variable "password" {
  description = "Password del usuario maestro"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "Clase de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "Version mayor del motor PostgreSQL"
  type        = string
  default     = "16"
}

variable "allocated_storage" {
  description = "Almacenamiento asignado en GB"
  type        = number
  default     = 20
}

variable "allowed_cidrs" {
  description = "CIDRs externos autorizados a conectar (para el seeding manual con un cliente SQL)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "force_ssl" {
  description = "Si true, RDS rechaza conexiones sin SSL (default en PostgreSQL 15+). Desactivar solo en dev."
  type        = bool
  default     = false
}
