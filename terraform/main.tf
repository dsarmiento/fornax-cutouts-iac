terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.96"
    }
  }

  # TODO: replace with your backend configuration
  backend "local" {}
}


provider "aws" {
  region = "us-east-1" # TODO: replace with your region
}


module "fornax_cutouts" {
  source = "./modules/fornax_cutouts"

  project_name = "fornax-cutouts" # TODO: replace with your project name
  account_id   = "123456789012"   # TODO: replace with your AWS account ID
  aws_region   = "us-east-1"      # TODO: replace with your region
  env          = "dev"            # TODO: replace with your environment name

  ecs_cluster = {
    container_insights    = "disabled"
    enable_spot_instances = false
  }

  network = {
    vpc_id                      = "vpc-00000000000000000"                                                               # TODO: replace with your VPC ID
    public_subnet_ids           = ["subnet-00000000000000000"]                                                          # TODO: replace with your public subnet IDs
    private_subnet_ids          = ["subnet-00000000000000000"]                                                          # TODO: replace with your private subnet IDs
    allowed_ingress_cidr_blocks = ["0.0.0.0/0"]                                                                         # TODO: restrict to your IP ranges
    acm_certificate_arn         = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000" # TODO: replace or set to null
  }

  elasticache = {
    node_type = "cache.t4g.micro" # TODO: adjust to your workload
  }

  cutouts_service = {
    image_url          = "123456789012.dkr.ecr.us-east-1.amazonaws.com/fornax-cutouts-example:latest" # TODO: replace with your image URI
    task_role_arn      = "arn:aws:iam::123456789012:role/CutoutsBackendECSTaskRole"                   # TODO: replace with your task role ARN
    execution_role_arn = "arn:aws:iam::123456789012:role/CutoutsECSTaskExecutionRole"                 # TODO: replace with your execution role ARN

    worker_settings = {
      batch_size_per_worker = 25
      prefetch_multiplier   = 2
      max_tasks_per_child   = 50
      high_mem_concurrency  = 2
      cutouts_enabled       = true
      cutouts_concurrency   = 16
    }

    log = {
      retention_days = 7
      format         = "json"
      level          = "INFO"
    }

    storage_prefix = "s3://my-bucket/cutouts" # TODO: replace with your S3 prefix

    extra_env_vars = []

    # datadog = {
    #   api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret/datadog-api-key"
    #   log_enabled        = true
    #   metrics_enabled    = true
    #   service_name       = "fornax-cutouts"
    #   source_name        = "aws"
    #   env_name           = "dev"
    #   additional_tags    = []
    # }
  }
}
