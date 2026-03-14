resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/datakeep/web"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-web-logs" }
}

resource "aws_cloudwatch_log_group" "jobs" {
  name              = "/ecs/datakeep/jobs"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-jobs-logs" }
}

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "/ecs/datakeep/migrate"
  retention_in_days = 14

  tags = { Name = "${local.name_prefix}-migrate-logs" }
}
