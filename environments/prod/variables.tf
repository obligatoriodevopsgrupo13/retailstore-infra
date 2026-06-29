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

variable "image_tag" {
  description = "Tag de la imagen Docker a desplegar en ECS"
  type        = string
  default     = "latest"
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

variable "alarm_email" {
  description = "Email para notificaciones de alarmas CloudWatch"
  type        = string
  default     = ""
}

variable "obs_cpu_threshold" {
  description = "% de CPU para disparar alarma ECS"
  type        = number
  default     = 80
}

variable "obs_memory_threshold" {
  description = "% de memoria para disparar alarma ECS"
  type        = number
  default     = 80
}

variable "obs_error_5xx_threshold" {
  description = "Cantidad de errores 5XX en 5 minutos para disparar alarma ALB"
  type        = number
  default     = 10
}

variable "obs_response_time_threshold" {
  description = "Tiempo de respuesta promedio en segundos para disparar alarma ALB"
  type        = number
  default     = 2
}

variable "obs_unhealthy_hosts_threshold" {
  description = "Cantidad de hosts no saludables para disparar alarma ALB"
  type        = number
  default     = 1
}