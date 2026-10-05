output "url" {
  value = module.workload.url
}

output "alb_dns_name" {
  value = module.workload.alb_dns_name
}

output "autoscaling_group_name" {
  value = module.workload.autoscaling_group_name
}

output "ami_id" {
  value = module.workload.ami_id
}

output "db_endpoint" {
  value = module.workload.db_endpoint
}

output "db_secret_arn" {
  value = module.workload.db_secret_arn
}

output "efs_id" {
  value = module.workload.efs_id
}

output "app_log_group" {
  value = module.workload.app_log_group
}
