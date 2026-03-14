# Auto-constructed from RDS endpoint
resource "aws_secretsmanager_secret" "database_url" {
  name = "datakeep/database-url"
  tags = { Name = "${local.name_prefix}-database-url" }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${aws_db_instance.main.username}:${random_password.db.result}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
}

# Auto-constructed from ElastiCache endpoint
resource "aws_secretsmanager_secret" "redis_url" {
  name = "datakeep/redis-url"
  tags = { Name = "${local.name_prefix}-redis-url" }
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/0"
}

# Set manually after first apply:
#   aws secretsmanager put-secret-value --secret-id datakeep/rails-master-key \
#     --secret-string "$(cat config/master.key)" --profile manifest --region eu-south-1
resource "aws_secretsmanager_secret" "rails_master_key" {
  name = "datakeep/rails-master-key"
  tags = { Name = "${local.name_prefix}-rails-master-key" }
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  secret_string = "CHANGE_ME"

  lifecycle { ignore_changes = [secret_string] }
}

# Auto-generated
resource "random_password" "secret_key_base" {
  length  = 128
  special = false
}

resource "aws_secretsmanager_secret" "secret_key_base" {
  name = "datakeep/secret-key-base"
  tags = { Name = "${local.name_prefix}-secret-key-base" }
}

resource "aws_secretsmanager_secret_version" "secret_key_base" {
  secret_id     = aws_secretsmanager_secret.secret_key_base.id
  secret_string = random_password.secret_key_base.result
}

# Set manually:
#   aws secretsmanager put-secret-value --secret-id datakeep/stripe-secret-key \
#     --secret-string "sk_live_..." --profile manifest --region eu-south-1
resource "aws_secretsmanager_secret" "stripe_secret_key" {
  name = "datakeep/stripe-secret-key"
  tags = { Name = "${local.name_prefix}-stripe-secret-key" }
}

resource "aws_secretsmanager_secret_version" "stripe_secret_key" {
  secret_id     = aws_secretsmanager_secret.stripe_secret_key.id
  secret_string = "CHANGE_ME"

  lifecycle { ignore_changes = [secret_string] }
}

# Set manually:
#   aws secretsmanager put-secret-value --secret-id datakeep/stripe-webhook-secret \
#     --secret-string "whsec_..." --profile manifest --region eu-south-1
resource "aws_secretsmanager_secret" "stripe_webhook_secret" {
  name = "datakeep/stripe-webhook-secret"
  tags = { Name = "${local.name_prefix}-stripe-webhook-secret" }
}

resource "aws_secretsmanager_secret_version" "stripe_webhook_secret" {
  secret_id     = aws_secretsmanager_secret.stripe_webhook_secret.id
  secret_string = "CHANGE_ME"

  lifecycle { ignore_changes = [secret_string] }
}

# Active Record Encryption keys (auto-generated, do not change after data is encrypted)
resource "aws_secretsmanager_secret" "ar_encryption_primary_key" {
  name = "datakeep/ar-encryption-primary-key"
  tags = { Name = "${local.name_prefix}-ar-primary-key" }
}

resource "aws_secretsmanager_secret" "ar_encryption_deterministic_key" {
  name = "datakeep/ar-encryption-deterministic-key"
  tags = { Name = "${local.name_prefix}-ar-deterministic-key" }
}

resource "aws_secretsmanager_secret" "ar_encryption_key_derivation_salt" {
  name = "datakeep/ar-encryption-key-derivation-salt"
  tags = { Name = "${local.name_prefix}-ar-key-derivation-salt" }
}
