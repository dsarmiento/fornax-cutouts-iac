# nasa-fornax-admin Policy
resource "aws_iam_role" "admin" {
  name               = "${var.project_name}-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "admin" {
  name   = "${var.project_name}-admin-policy"
  role   = aws_iam_role.admin.id
  policy = file("${path.module}/policies/nasa-fornax-admin.json")
}


# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "FornaxCutoutsECSTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "ecs_task_execution" {
  name   = "FornaxCutoutsECSTaskExecutionPolicy"
  role   = aws_iam_role.ecs_task_execution.id
  policy = file("${path.module}/policies/CutoutsECSTaskExecutionRole.json")
}


# ECS Backend Task Role
resource "aws_iam_role" "backend_ecs_task" {
  name = "FornaxCutoutsBackendECSTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "backend_ecs_task" {
  name   = "FornaxCutoutsBackendECSTaskPolicy"
  role   = aws_iam_role.backend_ecs_task.id
  policy = file("${path.module}/policies/CutoutsBackendECSTaskRole.json")
}


# Cloudwatch Lambda Role
resource "aws_iam_role" "lambda_role" {
  name = "FornaxCutoutsCloudwatchLambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "lambda_policy" {
  name = "FornaxCutoutsCloudwatchLambdaPolicy"
  role = aws_iam_role.lambda_role.id
  policy = file("${path.module}/policies/CutoutsCloudwatchLambda.json")
}
