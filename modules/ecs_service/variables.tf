variable "app_name" {
  description = "Nombre del servicio o aplicacion a desplegar"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue, por ejemplo dev, test o prod"
  type        = string
}

variable "cluster_id" {
  description = "ID del cluster ECS donde se ejecuta el servicio"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los recursos del servicio"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de subnets publicas donde se crea el Application Load Balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs de subnets privadas donde se ejecutan las tareas ECS"
  type        = list(string)
}

variable "image_url" {
  description = "URL completa de la imagen Docker a desplegar"
  type        = string
}

variable "image_tag" {
  description = "Tag de la imagen Docker a desplegar"
  type        = string
  default     = "latest"
}

variable "execution_role_arn" {
  description = "ARN del IAM role usado por ECS para ejecutar la task"
  type        = string
}

variable "container_port" {
  description = "Puerto expuesto por el contenedor"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU asignada a la task Fargate"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria asignada a la task Fargate en MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Cantidad deseada de tareas en ejecucion"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "Region de AWS donde se despliega el servicio"
  type        = string
  default     = "us-east-1"
}

variable "environment_variables" {
  description = "Variables de entorno no sensibles para el contenedor"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secretos para el contenedor referenciados desde Secrets Manager o SSM"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}
