locals {
  datadog_enabled = var.service.datadog != null

  datadog_service_name = local.datadog_enabled ? coalesce(var.service.datadog.service_name, var.project_name) : null
  datadog_env_name     = local.datadog_enabled ? coalesce(var.service.datadog.env_name, var.env) : null

  datadog_logs_enabled    = local.datadog_enabled && var.service.datadog.log_enabled
  datadog_metrics_enabled = local.datadog_enabled && var.service.datadog.metrics_enabled

  datadog_tags = local.datadog_enabled ? concat([
    "account:${var.account_id}",
    "region:${var.aws_region}",
    "env:${local.datadog_env_name}"
  ], var.service.datadog.additional_tags) : []

  datadog_log_tags = join(",", local.datadog_tags)
  datadog_metrics_tags = local.datadog_enabled ? join(" ", concat([
    "service:${local.datadog_service_name}",
    "source:${var.service.datadog.source_name}",
    ],
  local.datadog_tags)) : ""

  awslogs_options = {
    "awslogs-group"         = aws_cloudwatch_log_group.log_group.name
    "awslogs-region"        = var.aws_region
    "awslogs-stream-prefix" = var.service.name
  }

  datadog_firelens_options = local.datadog_logs_enabled ? {
    "Name"       = "datadog"
    "Host"       = "http-intake.logs.datadoghq.com"
    "dd_service" = local.datadog_service_name
    "dd_source"  = var.service.datadog.source_name
    "dd_tags"    = local.datadog_log_tags
  } : {}

  main_log_options = local.datadog_logs_enabled ? local.datadog_firelens_options : local.awslogs_options
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/${var.project_name}/${var.env}/ecs/${var.service.name}"
  retention_in_days = var.service.log_retention_days
}

# ECS Task Definition
resource "aws_ecs_task_definition" "task_def" {
  family                   = "${var.project_name}-${var.env}-${var.service.name}-def"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.service.cpu
  memory                   = var.service.memory
  execution_role_arn       = var.service.execution_role_arn
  task_role_arn            = var.service.task_role_arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode(concat(
    [
      {
        name      = var.service.name
        image     = var.service.image
        essential = true
        command   = var.service.command
        portMappings = var.service.port != null ? [{
          containerPort = var.service.port
          hostPort      = var.service.port
        }] : null
        logConfiguration = merge(
          {
            logDriver = local.datadog_logs_enabled ? "awsfirelens" : "awslogs"
            options   = local.main_log_options
          },
          {
            secretOptions = local.datadog_logs_enabled ? [
              {
                name      = "apikey"
                valueFrom = var.service.datadog.api_key_secret_arn
              }
            ] : []
          }
        )
        environment = var.service.environment
      }
    ],
    concat(
      [for _ in(local.datadog_metrics_enabled ? [1] : []) : {
        # Datadog agent sidecar container
        name      = "datadog-agent"
        image     = "public.ecr.aws/datadog/agent:latest"
        essential = false
        cpu       = 256
        memory    = 512
        portMappings = [{
          containerPort = 8126
          hostPort      = 8126
          protocol      = "tcp"
        }]
        secrets = [
          {
            name      = "DD_API_KEY"
            valueFrom = var.service.datadog.api_key_secret_arn
          }
        ]
        environment = [
          {
            name  = "DD_SITE"
            value = "datadoghq.com"
          },
          {
            name  = "DD_TAGS"
            value = local.datadog_metrics_tags
          },
          {
            name  = "DD_LOGS_ENABLED"
            value = "true"
          },
          {
            name  = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL"
            value = "true"
          },
          {
            name  = "DD_CONTAINER_EXCLUDE"
            value = "name:datadog-agent name:fluent-bit"
          },
          {
            name  = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
            value = "true"
          },
          {
            name  = "DD_APM_ENABLED"
            value = "true"
          },
          {
            name  = "DD_APM_NON_LOCAL_TRAFFIC"
            value = "true"
          },
          {
            name  = "ECS_FARGATE"
            value = "true"
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.log_group.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "datadog-agent"
          }
        }
      }],
      [for _ in(local.datadog_logs_enabled ? [1] : []) : {
        # Fluent Bit log forwarder sidecar container
        name      = "fluent-bit"
        image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
        essential = false
        cpu       = 128
        memory    = 256
        secrets = [
          {
            name      = "DD_API_KEY"
            valueFrom = var.service.datadog.api_key_secret_arn
          }
        ]
        environment = [
          {
            name  = "DD_SITE"
            value = "datadoghq.com"
          },
          {
            name  = "DD_SERVICE"
            value = local.datadog_service_name
          },
          {
            name  = "DD_ENV"
            value = local.datadog_env_name
          },
          {
            name  = "DD_SOURCE"
            value = var.service.datadog.source_name
          }
        ]
        firelensConfiguration = {
          type = "fluentbit"
          options = {
            enable-ecs-log-metadata = "true"
            config-file-type        = "file"
            config-file-value       = "/fluent-bit/configs/parse-json.conf"
          }
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.log_group.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "fluent-bit"
          }
        }
      }]
    )
  ))
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = "${var.project_name}-${var.env}-${var.service.name}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.task_def.arn
  launch_type     = "FARGATE"
  desired_count   = var.service.desired_count

  network_configuration {
    subnets          = var.network.private_subnet_ids
    assign_public_ip = false
    security_groups = concat(
      var.service.security_groups,
      var.service.port != null ? [aws_security_group.ecs_sg[0].id] : []
    )
  }

  dynamic "load_balancer" {
    for_each = var.service.lb != null ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.lb_tg[0].arn
      container_name   = var.service.name
      container_port   = var.service.port
    }
  }
}


# Auto Scaling
resource "aws_appautoscaling_target" "scaling_target" {
  count = var.service.scaling != null ? 1 : 0

  min_capacity       = var.service.scaling.min_capacity
  max_capacity       = var.service.scaling.max_capacity
  resource_id        = "service/${var.project_name}-${var.env}-cluster/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scaling_policy" {
  count = var.service.scaling != null ? 1 : 0

  name               = "${var.project_name}-${var.env}-${var.service.name}-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.scaling_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.scaling_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.service.scaling.target_value
    predefined_metric_specification {
      predefined_metric_type = var.service.scaling.metric
    }
    scale_in_cooldown  = var.service.scaling.scale_in_cooldown
    scale_out_cooldown = var.service.scaling.scale_out_cooldown
  }
}

# Networking

###############
# Security Group
###############

resource "aws_security_group" "ecs_sg" {
  count = var.service.port != null ? 1 : 0

  name   = "${var.project_name}-${var.env}-${var.service.name}-sg"
  vpc_id = var.network.vpc_id

  ingress {
    from_port       = var.service.port
    to_port         = var.service.port
    protocol        = "tcp"
    security_groups = [var.service.lb.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


###############
# Load Balancer
###############

resource "aws_lb_target_group" "lb_tg" {
  count = var.service.lb != null ? 1 : 0

  name        = "${var.project_name}-${var.env}-${var.service.name}-tg"
  port        = var.service.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.network.vpc_id

  health_check {
    path                = var.service.lb.health_path
    protocol            = "HTTP"
    port                = var.service.port
  }
}

resource "aws_lb_listener_rule" "lb_rule" {
  count = var.service.lb != null ? 1 : 0

  listener_arn = var.service.lb.listener_arn
  priority     = var.service.lb.rule_priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg[0].arn
  }
  condition {
    path_pattern {
      values = var.service.lb.rule_paths
    }
  }
}
