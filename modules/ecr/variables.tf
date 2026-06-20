variable "name" {
  description = "Nombre del repositorio ECR"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue, por ejemplo dev, test o prod"
  type        = string
}
