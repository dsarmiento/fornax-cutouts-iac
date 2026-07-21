variable "env" {
  type = string
}

variable "account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "project_name" {
  type    = string
  default = "nasa-fornax-cutouts"
}

variable "num_subnets" {
  type        = number
  description = "Number of public subnets and the same number of private subnets to create."
  default     = 2

  validation {
    condition     = var.num_subnets >= 1 && var.num_subnets <= 16
    error_message = "num_subnets must be between 1 and 16."
  }
}

variable "subnet_prefix" {
  type        = number
  description = "CIDR prefix length for each subnet (e.g., 27 for /27 = 32 addresses). The VPC CIDR is computed to be just large enough to hold 2 x num_subnets subnets of this size."
  default     = 27

  validation {
    condition     = var.subnet_prefix >= 20 && var.subnet_prefix <= 28
    error_message = "subnet_prefix must be between 20 (/20) and 28 (/28)."
  }
}

variable "cutout_prefix_ttl_days" {
  type        = number
  description = "Number of days to keep cutouts in the stage bucket."
  default     = 1

  validation {
    condition     = var.cutout_prefix_ttl_days >= 1 && var.cutout_prefix_ttl_days <= 30
    error_message = "cutout_prefix_ttl_days must be between 1 and 30."
  }
}