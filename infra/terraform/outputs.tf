output "alb_dns_name" {
  description = "ALB DNS name — point Cloudflare CNAME here"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "web_service_name" {
  description = "ECS web service name"
  value       = aws_ecs_service.web.name
}

output "jobs_service_name" {
  description = "ECS jobs service name"
  value       = aws_ecs_service.jobs.name
}

