variable "image_tag" {
  type = string
  description = "The image tag to deploy"
  default = "latest"
}

variable "account_id" {
  type = string
  description = "The AWS account ID"
}

variable "aws_region" {
  type = string
  description = "The AWS region"
  default = "us-east-1"
}

variable "project_name" {
  type = string
  description = "The name of the project"
  default = "nasa-fornax-cutouts"
}

variable "env" {
  type = string
  description = "The environment name (e.g. dev, test)"
  default = "dev"
}
