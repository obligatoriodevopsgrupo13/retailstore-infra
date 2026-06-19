variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue, por ejemplo dev, test o prod"
  type        = string
}
