variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "fornax-cutouts"
}

variable "env" {
  type        = string
  description = "The environment name (e.g. dev, test)"
}

variable "account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
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

variable "ecs_cluster_id" {
  type = string
  description = "The ECS cluster ID"
}

variable "service" {
  type = object({
    name               = string
    port               = number
    cpu                = number
    memory             = number
    execution_role_arn = string
    task_role_arn      = optional(string)
    log_retention_days = optional(number, 1)

    image   = string
    command = optional(list(string), [])
    environment = optional(list(
      object({
        name  = string
        value = string
      })),
      []
    )

    desired_count   = number
    security_groups = optional(list(string), [])

    lb = optional(object({
      health_path       = string
      rule_priority     = number
      rule_paths        = list(string)
      listener_arn      = string
      security_group_id = string
    }), null)

    scaling = optional(object({
      min_capacity       = number
      max_capacity       = number
      metric             = string
      target_value       = number
      scale_in_cooldown  = number
      scale_out_cooldown = number
    }), null)

    # Datadog configuration
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
}
