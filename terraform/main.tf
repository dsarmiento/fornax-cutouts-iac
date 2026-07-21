terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.96"
    }
  }

  # TODO: replace with your Terraform backend configuration (e.g. S3 + DynamoDB)
  backend "local" {
    path = "./terraform.tfstate"
  }
}


provider "aws" {
  region = var.aws_region
}


module "sandbox" {
  source = "./modules/sandbox"

  env          = var.env
  project_name = var.project_name
  account_id   = var.account_id
  aws_region   = var.aws_region

  num_subnets   = 2  # The number of public and private subnets to create
  subnet_prefix = 27 # The CIDR prefix length for each subnet (e.g., 27 for /27 = 32 addresses)

  cutout_prefix_ttl_days = 1 # The number of days to keep cutouts in the stage bucket
}


module "fornax_cutouts" {
  source = "./modules/fornax_cutouts"

  env          = var.env
  project_name = var.project_name

  account_id = var.account_id
  aws_region = var.aws_region

  ecs_cluster = {
    container_insights    = "disabled"
    enable_spot_instances = false
  }

  network = {
    vpc_id                      = module.sandbox.vpc_id             # TODO: replace with your VPC ID
    public_subnet_ids           = module.sandbox.public_subnet_ids  # TODO: replace with your public subnet IDs
    private_subnet_ids          = module.sandbox.private_subnet_ids # TODO: replace with your private subnet IDs
    allowed_ingress_cidr_blocks = ["0.0.0.0/0"]                     # TODO: restrict to your IP ranges if needed, leave blank for fully public
  }

  elasticache = {
    node_type = "cache.t4g.micro" # TODO: adjust to your workload
  }

  cutouts_service = {
    image_url          = "${module.sandbox.backend_repo_url}:${var.image_tag}"
    task_role_arn      = module.sandbox.role_arns.backend_ecs_task   # TODO: replace with your task role ARN
    execution_role_arn = module.sandbox.role_arns.ecs_task_execution # TODO: replace with your execution role ARN

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

    storage_prefix = "s3://${module.sandbox.stage_bucket_name}/cutouts" # TODO: replace with your S3 prefix

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
