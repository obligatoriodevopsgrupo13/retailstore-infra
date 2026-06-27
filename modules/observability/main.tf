# ─────────────────────────────────────────────
# Locals: extraer sufijos de ARN para CloudWatch
# CloudWatch necesita solo la parte después de "loadbalancer/" y "targetgroup/"
# ─────────────────────────────────────────────
locals {
  # Convierte ARN completo => sufijo que usa CloudWatch
  # ej: "arn:aws:elasticloadbalancing:us-east-1:123:loadbalancer/app/retail-catalog-dev/abc123"
  #     => "app/retail-catalog-dev/abc123"
  services_with_suffixes = {
    for name, svc in var.services : name => {
      service_name            = svc.service_name
      alb_arn_suffix          = replace(svc.alb_arn, "/^.*:loadbalancer\\//", "")
      target_group_arn_suffix = replace(svc.target_group_arn, "/^.*::targetgroup\\//", "targetgroup/")
    }
  }

  # Solo los servicios críticos que existen en var.services
  critical = {
    for name, svc in local.services_with_suffixes :
    name => svc if contains(var.critical_services, name)
  }
}

# ─────────────────────────────────────────────
# SNS Topic para notificaciones de alarmas
# ─────────────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "${var.app_name}-alarms-${var.environment}"

  tags = {
    environment = var.environment
    app         = var.app_name
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ─────────────────────────────────────────────
# Alarmas ECS CPU — servicios críticos
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = local.critical

  alarm_name          = "${each.key}-cpu-high-${var.environment}"
  alarm_description   = "CPU de ${each.key} superó ${var.cpu_threshold}% durante 10 minutos"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value.service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    environment = var.environment
    service     = each.key
  }
}

# ─────────────────────────────────────────────
# Alarmas ECS Memoria — servicios críticos
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = local.critical

  alarm_name          = "${each.key}-memory-high-${var.environment}"
  alarm_description   = "Memoria de ${each.key} superó ${var.memory_threshold}% durante 10 minutos"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value.service_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    environment = var.environment
    service     = each.key
  }
}

# ─────────────────────────────────────────────
# Alarma ALB 5XX — todos los servicios
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  for_each = local.services_with_suffixes

  alarm_name          = "${each.key}-alb-5xx-${var.environment}"
  alarm_description   = "Más de ${var.error_5xx_threshold} errores 5XX en ${each.key} en 5 minutos"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    environment = var.environment
    service     = each.key
  }
}

# ─────────────────────────────────────────────
# Alarma Hosts no saludables — todos los servicios
# ─────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  for_each = local.services_with_suffixes

  alarm_name          = "${each.key}-unhealthy-hosts-${var.environment}"
  alarm_description   = "Hay hosts no saludables en ${each.key}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.unhealthy_hosts_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    environment = var.environment
    service     = each.key
  }
}

# ─────────────────────────────────────────────
# Dashboard consolidado — todos los servicios
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = concat(
      # ── Fila 0: Título ──
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 2
          properties = {
            markdown = "# RetailStore — Observabilidad (${var.environment})\nMonitoreo de los 6 microservicios: UI · Admin · Catalog · Cart · Checkout · Orders"
          }
        }
      ],

      # ── Fila 1: CPU por servicio (todos) ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 2
          width  = 24
          height = 6
          properties = {
            title  = "CPU Utilization — todos los servicios (%)"
            region = var.aws_region
            period = 300
            stat   = "Average"
            view   = "timeSeries"
            metrics = [
              for name, svc in local.services_with_suffixes :
              ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", svc.service_name, { label = name }]
            ]
            annotations = {
              horizontal = [{ value = var.cpu_threshold, label = "Umbral CPU", color = "#ff6961" }]
            }
            yAxis = { left = { min = 0, max = 100 } }
          }
        }
      ],

      # ── Fila 2: Memoria por servicio (todos) ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 8
          width  = 24
          height = 6
          properties = {
            title  = "Memory Utilization — todos los servicios (%)"
            region = var.aws_region
            period = 300
            stat   = "Average"
            view   = "timeSeries"
            metrics = [
              for name, svc in local.services_with_suffixes :
              ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", svc.service_name, { label = name }]
            ]
            annotations = {
              horizontal = [{ value = var.memory_threshold, label = "Umbral Memoria", color = "#ff6961" }]
            }
            yAxis = { left = { min = 0, max = 100 } }
          }
        }
      ],

      # ── Fila 3: Request Count + 5XX por servicio ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "ALB Request Count — todos los servicios"
            region = var.aws_region
            period = 300
            stat   = "Sum"
            view   = "timeSeries"
            metrics = [
              for name, svc in local.services_with_suffixes :
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", svc.alb_arn_suffix, { label = name }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 14
          width  = 12
          height = 6
          properties = {
            title  = "ALB 5XX Errors — todos los servicios"
            region = var.aws_region
            period = 300
            stat   = "Sum"
            view   = "timeSeries"
            metrics = [
              for name, svc in local.services_with_suffixes :
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", svc.alb_arn_suffix, "TargetGroup", svc.target_group_arn_suffix, { label = name }]
            ]
            annotations = {
              horizontal = [{ value = var.error_5xx_threshold, label = "Umbral 5XX", color = "#ff6961" }]
            }
          }
        }
      ],

      # ── Fila 4: Response Time + Healthy/Unhealthy Hosts ──
      [
        {
          type   = "metric"
          x      = 0
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "ALB Target Response Time — todos los servicios (s)"
            region = var.aws_region
            period = 300
            stat   = "Average"
            view   = "timeSeries"
            metrics = [
              for name, svc in local.services_with_suffixes :
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", svc.alb_arn_suffix, "TargetGroup", svc.target_group_arn_suffix, { label = name }]
            ]
            annotations = {
              horizontal = [{ value = var.response_time_threshold, label = "Umbral latencia", color = "#ff6961" }]
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 20
          width  = 12
          height = 6
          properties = {
            title  = "ALB Healthy / Unhealthy Hosts — todos los servicios"
            region = var.aws_region
            period = 60
            stat   = "Average"
            view   = "timeSeries"
            metrics = concat(
              [
                for name, svc in local.services_with_suffixes :
                ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", svc.alb_arn_suffix, "TargetGroup", svc.target_group_arn_suffix, { label = "${name}-healthy", color = "#2ca02c" }]
              ],
              [
                for name, svc in local.services_with_suffixes :
                ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", svc.alb_arn_suffix, "TargetGroup", svc.target_group_arn_suffix, { label = "${name}-unhealthy", color = "#d62728" }]
              ]
            )
          }
        }
      ],

      # ── Fila 5: Estado de alarmas ──
      [
        {
          type   = "alarm"
          x      = 0
          y      = 26
          width  = 24
          height = 6
          properties = {
            title = "Estado de Alarmas — servicios críticos (checkout · orders · cart)"
            alarms = concat(
              [for k, v in aws_cloudwatch_metric_alarm.ecs_cpu_high : v.arn],
              [for k, v in aws_cloudwatch_metric_alarm.ecs_memory_high : v.arn],
              [for k, v in aws_cloudwatch_metric_alarm.alb_5xx_errors : v.arn],
              [for k, v in aws_cloudwatch_metric_alarm.alb_unhealthy_hosts : v.arn]
            )
          }
        }
      ]
    )
  })
}
