# One-off migration task — run via `make migrate` or scripts/migrate.sh
# No service, invoked with `aws ecs run-task`

resource "aws_ecs_task_definition" "migrate" {
  family                   = "${local.name_prefix}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "migrate"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    command   = ["./bin/rails", "db:migrate"]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
    ]

    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      { name = "RAILS_MASTER_KEY", valueFrom = aws_secretsmanager_secret.rails_master_key.arn },
      { name = "SECRET_KEY_BASE", valueFrom = aws_secretsmanager_secret.secret_key_base.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", valueFrom = aws_secretsmanager_secret.ar_encryption_primary_key.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", valueFrom = aws_secretsmanager_secret.ar_encryption_deterministic_key.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", valueFrom = aws_secretsmanager_secret.ar_encryption_key_derivation_salt.arn },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.migrate.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "migrate"
      }
    }
  }])

  tags = { Name = "${local.name_prefix}-migrate-task" }
}
