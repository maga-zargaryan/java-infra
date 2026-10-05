resource "aws_db_parameter_group" "this" {
  name        = local.name
  family      = "mysql8.4"
  description = "${local.name} MySQL parameters"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }
}

locals {
  db_log_exports = ["error", "slowquery"]
}

# Created up front so exported logs get retention and encryption.
resource "aws_cloudwatch_log_group" "db" {
  for_each = toset(local.db_log_exports)

  name              = "/aws/rds/instance/${local.name}/${each.value}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = local.kms_key_arn
}

resource "aws_db_instance" "this" {
  identifier     = local.name
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = local.kms_key_arn

  db_name  = var.db_name
  username = "admin"
  # RDS generates, stores and rotates the password in Secrets Manager.
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = local.kms_key_arn
  iam_database_authentication_enabled = true

  db_subnet_group_name   = local.platform.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az
  parameter_group_name   = aws_db_parameter_group.this.name
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  backup_retention_period    = var.db_backup_retention_days
  backup_window              = "02:00-03:00"
  maintenance_window         = "sun:03:30-sun:04:30"
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  apply_immediately          = false

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = !var.db_final_snapshot
  final_snapshot_identifier = var.db_final_snapshot ? "${local.name}-final" : null

  enabled_cloudwatch_logs_exports       = local.db_log_exports
  performance_insights_enabled          = var.db_performance_insights
  performance_insights_kms_key_id       = var.db_performance_insights ? local.kms_key_arn : null
  performance_insights_retention_period = var.db_performance_insights ? 7 : null

  depends_on = [aws_cloudwatch_log_group.db]
}
