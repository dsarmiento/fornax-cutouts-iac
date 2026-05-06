locals {
  cache_cluster = {
    is_cluster = aws_elasticache_replication_group.valkey.cluster_mode == "enabled"
    endpoint   = aws_elasticache_replication_group.valkey.cluster_mode == "enabled" ? aws_elasticache_replication_group.valkey.configuration_endpoint_address : aws_elasticache_replication_group.valkey.primary_endpoint_address
    port       = aws_elasticache_replication_group.valkey.port
  }

  cutouts_env_vars = concat([
    {
      name  = "CUTOUTS__DEPLOYMENT_ENVIRONMENT"
      value = "${var.env}"
    },
    {
      name  = "CUTOUTS__REDIS__HOST"
      value = "${local.cache_cluster.endpoint}"
    },
    {
      name  = "CUTOUTS__REDIS__PORT"
      value = "${local.cache_cluster.port}"
    },
    {
      name  = "CUTOUTS__REDIS__IS_CLUSTER"
      value = "${local.cache_cluster.is_cluster}"
    },
    {
      name  = "CUTOUTS__REDIS__USE_SSL"
      value = "TRUE"
    },
    {
      name  = "CUTOUTS__ASYNC_TTL"
      value = "${2 * 60 * 60}" # 2 hours
    },
    {
      name  = "CUTOUTS__WORKER__BATCH_SIZE_PER_WORKER"
      value = "${var.cutouts_service.worker_settings.batch_size_per_worker}"
    },
    {
      name  = "CUTOUTS__WORKER__PREFETCH_MULTIPLIER"
      value = "${var.cutouts_service.worker_settings.prefetch_multiplier}"
    },
    {
      name  = "CUTOUTS__WORKER__MAX_TASKS_PER_CHILD"
      value = "${var.cutouts_service.worker_settings.max_tasks_per_child}"
    },
    {
      name  = "CUTOUTS__DEPLOYMENT_TYPE"
      value = "aws"
    },
    {
      name  = "CUTOUTS__STORAGE__PREFIX"
      value = "${var.cutouts_service.storage_prefix}"
    },
    {
      name  = "CUTOUTS__LOG__FORMAT"
      value = "${var.cutouts_service.log.format}"
    },
    {
      name  = "CUTOUTS__LOG__LEVEL"
      value = "${var.cutouts_service.log.level}"
    }
    ],
  var.cutouts_service.extra_env_vars)

  backend_service = {
    name               = "backend"
    port               = 8000
    cpu                = 512
    memory             = 1024
    log_retention_days = var.cutouts_service.log.retention_days

    image       = var.cutouts_service.image_url
    command     = ["api"]
    environment = local.cutouts_env_vars

    desired_count = 1

    security_groups = [aws_security_group.ecs_cache_sg.id]
    lb = {
      health_path       = "/api/health"
      rule_priority     = 100
      rule_paths        = ["/api/*"]
      listener_arn      = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
      security_group_id = aws_security_group.alb_sg.id
    }
    scaling = null
  }

  cutouts_worker_service = {
    name               = "cutouts_worker"
    port               = null
    cpu                = 1024
    memory             = 3072
    log_retention_days = var.cutouts_service.log.retention_days

    image       = var.cutouts_service.image_url
    command     = ["worker", "--queues", "cutouts", "--concurrency", "${var.cutouts_service.worker_settings.cutouts_concurrency}"]
    environment = local.cutouts_env_vars

    desired_count = 2

    security_groups = [aws_security_group.ecs_cache_sg.id]
    lb      = null
    scaling = null
  }

  high_mem_worker_service = {
    name               = "high_mem_worker"
    port               = null
    cpu                = 1024
    memory             = 4096
    log_retention_days = var.cutouts_service.log.retention_days

    image       = var.cutouts_service.image_url
    command     = ["worker", "--queues", "high_mem,cutouts", "--concurrency", "${var.cutouts_service.worker_settings.high_mem_concurrency}"]
    environment = local.cutouts_env_vars

    desired_count = 1

    security_groups = [aws_security_group.ecs_cache_sg.id]
    lb      = null
    scaling = null
  }

  ecs_services = concat(
    [local.backend_service],
    var.cutouts_service.worker_settings.cutouts_enabled ? [local.cutouts_worker_service] : [],
    [local.high_mem_worker_service],
  )
}

module "ecs_services" {
  source   = "../ecs_service"
  for_each = { for s in local.ecs_services : s.name => s }

  project_name = var.project_name
  env          = var.env
  account_id   = var.account_id
  aws_region   = var.aws_region

  ecs_cluster_id = aws_ecs_cluster.ecs_cluster.id

  network = {
    vpc_id                      = var.network.vpc_id
    public_subnet_ids           = var.network.public_subnet_ids
    private_subnet_ids          = var.network.private_subnet_ids
    allowed_ingress_cidr_blocks = var.network.allowed_ingress_cidr_blocks
    acm_certificate_arn         = try(var.network.acm_certificate_arn, null)
  }

  service = {
    name               = each.value.name
    port               = each.value.port
    cpu                = each.value.cpu
    memory             = each.value.memory
    execution_role_arn = var.cutouts_service.execution_role_arn
    task_role_arn      = var.cutouts_service.task_role_arn
    log_retention_days = each.value.log_retention_days

    image       = each.value.image
    command     = each.value.command
    environment = each.value.environment

    desired_count   = each.value.desired_count
    security_groups = each.value.security_groups

    lb      = each.value.lb
    scaling = each.value.scaling
    datadog = var.cutouts_service.datadog
  }
}
