output "alb_dns_name" {
  value       = module.fornax_cutouts.alb_dns_name
  description = "Public DNS name of the cutouts API load balancer"
}

output "ecr_repository_url" {
  value       = module.sandbox.backend_repo_url
  description = "ECR repository URL for the service image (without tag)"
}

output "stage_bucket_name" {
  value       = module.sandbox.stage_bucket_name
  description = "S3 bucket for cutout results and mission metadata"
}
