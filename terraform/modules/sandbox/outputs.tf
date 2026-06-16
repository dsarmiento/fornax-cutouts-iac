output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "stage_bucket_name" {
  value = aws_s3_bucket.stage_bucket.bucket
}

output "role_arns" {
  value = {
    ecs_task_execution     = aws_iam_role.ecs_task_execution.arn
    backend_ecs_task       = aws_iam_role.backend_ecs_task.arn
    cloudwatch_lambda_role = aws_iam_role.lambda_role.arn
  }
}

output "backend_repo_url" {
  value = aws_ecr_repository.backend_repo.repository_url
}
