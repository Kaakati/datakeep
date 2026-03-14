resource "aws_elasticache_subnet_group" "main" {
  name       = local.name_prefix
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name_prefix}-redis-subnet" }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = local.name_prefix
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = { Name = "${local.name_prefix}-redis" }
}
