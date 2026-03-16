# ------------------------------------------------------------------------------
# Jobs Service — EC2 launch type (required for NET_ADMIN/NET_RAW VPN caps)
# Cannot use Fargate: VPN tunneling needs Linux capabilities + /dev/net/tun
# ------------------------------------------------------------------------------

# ECS-optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_launch_template" "jobs" {
  name_prefix   = "${local.name_prefix}-jobs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.large"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_ec2.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_TASK_IAM_ROLE=true" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name_prefix}-jobs-ec2" }
  }
}

resource "aws_autoscaling_group" "jobs" {
  name_prefix         = "${local.name_prefix}-jobs-"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.jobs.id
    version = "$Latest"
  }

  protect_from_scale_in = true

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-jobs-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_task_definition" "jobs" {
  family                   = "${local.name_prefix}-jobs"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "jobs"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    command   = ["bundle", "exec", "sidekiq"]

    linuxParameters = {
      initProcessEnabled = true
      capabilities = {
        add = ["NET_ADMIN", "NET_RAW"]
      }
      devices = [{
        hostPath      = "/dev/net/tun"
        containerPath = "/dev/net/tun"
        permissions   = ["read", "write", "mknod"]
      }]
    }

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
      { name = "SIDEKIQ_CONCURRENCY", value = "25" },
      { name = "SKIP_DB_PREPARE", value = "true" },
      { name = "APP_HOST", value = "datakeep.ai" },
      { name = "SMTP_ADDRESS", value = "email-smtp.eu-central-1.amazonaws.com" },
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
      { name = "SMTP_USERNAME", valueFrom = aws_secretsmanager_secret.smtp_username.arn },
      { name = "SMTP_PASSWORD", valueFrom = aws_secretsmanager_secret.smtp_password.arn },
    ]

    mountPoints = [
      { sourceVolume = "storage", containerPath = "/rails/storage", readOnly = false },
      { sourceVolume = "backups", containerPath = "/rails/backups", readOnly = false },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.jobs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "jobs"
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

  tags = { Name = "${local.name_prefix}-jobs-task" }
}

resource "aws_ecs_service" "jobs" {
  name            = "${local.name_prefix}-jobs"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.jobs.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
    base              = 1
  }

  enable_execute_command = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = { Name = "${local.name_prefix}-jobs-service" }
}
