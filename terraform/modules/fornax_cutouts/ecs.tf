resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project_name}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = var.ecs_cluster.container_insights
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity" {
  count = var.ecs_cluster.enable_spot_instances ? 1 : 0

  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
    base              = 0
  }
}
