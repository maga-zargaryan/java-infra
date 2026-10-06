# Settings the app AMI's boot-time configurator reads (no user data). The
# instance finds them through its Environment tag: /java-platform/<env>/app/*.
locals {
  runtime_settings = {
    server_port         = tostring(var.app_port)
    java_opts           = var.java_opts
    db_host             = aws_db_instance.this.address
    db_port             = tostring(aws_db_instance.this.port)
    db_name             = aws_db_instance.this.db_name
    db_secret_arn       = aws_db_instance.this.master_user_secret[0].secret_arn
    efs_id              = aws_efs_file_system.this.id
    efs_access_point_id = aws_efs_access_point.app.id
    log_group           = aws_cloudwatch_log_group.app.name
  }
}

resource "aws_ssm_parameter" "runtime" {
  for_each = local.runtime_settings

  name  = "/java-platform/${var.environment}/app/${each.key}"
  type  = "String"
  value = each.value
}
