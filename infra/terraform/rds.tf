# ------------------------------------------------------------------------------
# RDS PostgreSQL — db.t3.micro (lean mode, ~$17/mo)
# Upgrade path: db.t3.small (2 GB RAM) or db.t3.medium (4 GB RAM)
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = local.name_prefix
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name_prefix}-db-subnet" }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_instance" "main" {
  identifier = local.name_prefix

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  db_name  = "datakeep_production"
  username = "datakeep"
  password = random_password.db.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period   = 7
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-final"

  performance_insights_enabled = true

  tags = { Name = "${local.name_prefix}-rds" }
}
