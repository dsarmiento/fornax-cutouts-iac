variable "image_tag" {
  type        = string
  description = "The image tag to deploy"
  default     = "latest"
}

variable "account_id" {
  type        = string
  description = "The AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "fornax-cutouts"
  validation {
    condition     = length(var.project_name) <= 16
    error_message = "Project name must be less than or equal to 16 characters long"
  }
}

variable "env" {
  type        = string
  description = "The environment name (e.g. dev, test)"
  default     = "dev"
  validation {
    condition     = length(var.env) <= 4
    error_message = "Environment name must be less than or equal to 4 characters long"
  }
}
