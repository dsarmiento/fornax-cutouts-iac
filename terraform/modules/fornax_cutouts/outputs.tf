output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "The DNS name of the ALB"
}

output "ecs_cluster_id" {
  value       = aws_ecs_cluster.ecs_cluster.id
  description = "The ID of the ECS cluster"
}

output "alb_listener_arn" {
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  description = "The ARN of the ALB listener"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb_sg.id
  description = "The ID of the ALB security group"
}
