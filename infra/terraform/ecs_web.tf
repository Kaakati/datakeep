# ------------------------------------------------------------------------------
# Web Service — Fargate Spot (1 task, scales 1-2)
# Lean mode: FARGATE_SPOT 4:1 weight over FARGATE for ~70% cost savings
# Upgrade: bump desired_count + max_count, switch to FARGATE for guaranteed SLA
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.name_prefix}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "web"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    command   = ["./bin/thrust", "./bin/rails", "server"]

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
      { name = "RAILS_SERVE_STATIC_FILES", value = "true" },
      { name = "WEB_CONCURRENCY", value = "2" },
      { name = "RAILS_MAX_THREADS", value = "3" },
      { name = "SKIP_DB_PREPARE", value = "true" },
      { name = "HTTP_PORT", value = "8080" },
      { name = "APP_BASE_URL", value = "https://datakeep.ai" },
      { name = "APP_HOST", value = "datakeep.ai" },
      { name = "AWS_SES_REGION", value = var.aws_region },
    ]

    secrets = [
      { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
      { name = "REDIS_URL", valueFrom = aws_secretsmanager_secret.redis_url.arn },
      { name = "RAILS_MASTER_KEY", valueFrom = aws_secretsmanager_secret.rails_master_key.arn },
      { name = "SECRET_KEY_BASE", valueFrom = aws_secretsmanager_secret.secret_key_base.arn },
      { name = "STRIPE_SECRET_KEY", valueFrom = aws_secretsmanager_secret.stripe_secret_key.arn },
      { name = "STRIPE_WEBHOOK_SECRET", valueFrom = aws_secretsmanager_secret.stripe_webhook_secret.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", valueFrom = aws_secretsmanager_secret.ar_encryption_primary_key.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", valueFrom = aws_secretsmanager_secret.ar_encryption_deterministic_key.arn },
      { name = "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", valueFrom = aws_secretsmanager_secret.ar_encryption_key_derivation_salt.arn },
      { name = "TURNSTILE_SITE_KEY", valueFrom = aws_secretsmanager_secret.turnstile_site_key.arn },
      { name = "TURNSTILE_SECRET_KEY", valueFrom = aws_secretsmanager_secret.turnstile_secret_key.arn },
      { name = "GOOGLE_CLIENT_ID", valueFrom = aws_secretsmanager_secret.google_client_id.arn },
      { name = "GOOGLE_CLIENT_SECRET", valueFrom = aws_secretsmanager_secret.google_client_secret.arn },
    ]

    mountPoints = [
      { sourceVolume = "storage", containerPath = "/rails/storage", readOnly = false },
      { sourceVolume = "backups", containerPath = "/rails/backups", readOnly = false },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "web"
      }
    }
  }])

  volume {
    name = "storage"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.main.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.storage.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "backups"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.main.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.backups.id
        iam             = "ENABLED"
      }
    }
  }

  tags = { Name = "${local.name_prefix}-web-task" }
}

resource "aws_ecs_service" "web" {
  name            = "${local.name_prefix}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.web_desired_count

  # Fargate Spot — 80% preference for Spot, 20% on-demand fallback
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 8080
  }

  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.https]

  tags = { Name = "${local.name_prefix}-web-service" }
}
