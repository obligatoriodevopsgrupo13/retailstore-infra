variable "app_name" {
  description = "Nombre de la aplicación (prefijo para recursos)"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, test, prod)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde se despliegan los recursos"
  type        = string
  default     = "us-east-1"
}

variable "alarm_email" {
  description = "Email para notificaciones SNS (vacío = sin suscripción)"
  type        = string
  default     = ""
}

# Mapa de servicios: nombre => { alb_arn, target_group_arn, service_name }
variable "services" {
  description = "Mapa con los datos de cada microservicio para las métricas"
  type = map(object({
    alb_arn          = string
    target_group_arn = string
    service_name     = string
  }))
}

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

# Umbrales de alarmas
variable "cpu_threshold" {
  description = "% de CPU para disparar alarma"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "% de memoria para disparar alarma"
  type        = number
  default     = 80
}

variable "error_5xx_threshold" {
  description = "Cantidad de errores 5XX en 5 minutos para disparar alarma"
  type        = number
  default     = 10
}

variable "response_time_threshold" {
  description = "Tiempo de respuesta promedio en segundos para disparar alarma"
  type        = number
  default     = 2
}

variable "unhealthy_hosts_threshold" {
  description = "Cantidad de hosts no saludables para disparar alarma"
  type        = number
  default     = 1
}

# Servicios críticos que tendrán alarmas individuales
variable "critical_services" {
  description = "Lista de nombres de servicios que tendrán alarmas individuales de CPU/memoria"
  type        = list(string)
  default     = ["retail-checkout", "retail-orders", "retail-cart"]
}
