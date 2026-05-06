variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "fornax-cutouts"
}

variable "account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
}

variable "env" {
  type        = string
  description = "The environment name (e.g. dev, test)"
}

variable "ecs_cluster" {
  type = object({
    container_insights    = optional(string, "disabled")
    enable_spot_instances = optional(bool, false)
  })
  description = "The ECS cluster configuration"
}

variable "network" {
  type = object({
    vpc_id                      = string
    public_subnet_ids           = list(string)
    private_subnet_ids          = list(string)
    allowed_ingress_cidr_blocks = list(string)
    acm_certificate_arn         = optional(string, null)
  })
  description = "The network configuration"
}

variable "elasticache" {
  type = object({
    node_type = string
  })
  description = "The Elasticache configuration"
}


variable "cutouts_service" {
  type = object({
    image_url          = string
    task_role_arn      = string
    execution_role_arn = string

    worker_settings = object({
      batch_size_per_worker = optional(number, 25)
      prefetch_multiplier   = optional(number, 2)
      max_tasks_per_child   = optional(number, 50)

      # High memory is always required to serve both queues
      high_mem_concurrency = optional(number, 2)

      # Cutouts is optional, but if enabled, it will be dedicated to cutouts
      cutouts_enabled     = optional(bool, true)
      cutouts_concurrency = optional(number, 16)
    })

    log = object({
      retention_days = optional(number, 7)
      format         = optional(string, "json")
      level          = optional(string, "INFO")
    })

    storage_prefix = string

    extra_env_vars = optional(list(object({
      name  = string
      value = string
    })), [])

    datadog = optional(object({
      api_key_secret_arn = string
      log_enabled        = optional(bool, true)
      metrics_enabled    = optional(bool, true)
      service_name       = optional(string)
      source_name        = optional(string, "aws")
      env_name           = optional(string)
      additional_tags    = optional(list(string), [])
    }), null)
  })
  description = "The cutouts service configuration"
}
