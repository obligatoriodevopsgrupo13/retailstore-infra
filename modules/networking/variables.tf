variable "vpc_name" {
  description = "Nombre base para la VPC y recursos de red asociados"
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
  description = "Zonas de disponibilidad donde se crean las subnets"
  type        = list(string)
}

variable "environment" {
  description = "Ambiente al que pertenecen los recursos, por ejemplo dev, test o prod"
  type        = string
}
