resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.project_name}-${var.env}-cache-subnet-group"
  subnet_ids = var.network.private_subnet_ids
}

resource "aws_elasticache_replication_group" "valkey" {
  description          = "Cache DB for ${var.project_name} service"
  replication_group_id = "${var.project_name}-${var.env}-valkey"

  engine               = "valkey"
  engine_version       = "8.2"
  parameter_group_name = "default.valkey8"
  node_type            = var.elasticache.node_type
  num_cache_clusters   = 1
  port                 = 6379

  security_group_ids         = [aws_security_group.cache.id]
  subnet_group_name          = aws_elasticache_subnet_group.cache.name
  transit_encryption_enabled = true
}

# Security Group for the Elasticache
resource "aws_security_group" "ecs_cache_sg" {
  name        = "${var.project_name}-${var.env}-cache-sg-egress"
  description = "Security group for ECS tasks to access the cache"
  vpc_id      = var.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "cache" {
  name        = "${var.project_name}-${var.env}-cache-sg-ingress"
  description = "Allow ECS tasks to access the in memory db"
  vpc_id      = var.network.vpc_id

  ingress {
    description     = "Allow cache access from ECS tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_cache_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
