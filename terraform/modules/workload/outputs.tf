output "url" {
  value = "https://${local.domain_name}"
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}

output "ami_id" {
  value = local.ami_id
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_secret_arn" {
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}

output "app_log_group" {
  value = aws_cloudwatch_log_group.app.name
}
