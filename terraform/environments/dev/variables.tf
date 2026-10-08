variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "environment" {
  description = "Environment name; selects the platform contract under /java-platform/<environment>/."
  type        = string
}

variable "ami_id" {
  description = "Exact app AMI this environment runs."
  type        = string
}


variable "app_port" {
  description = "Port the application listens on."
  type        = number
}

variable "health_check_path" {
  description = "HTTP path returning 200 when the application is healthy."
  type        = string
}

variable "java_opts" {
  description = "JVM options."
  type        = string
}

variable "instance_type" {
  description = "Graviton instance type for application instances."
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GiB."
  type        = number
}

variable "asg_min_size" {
  description = "Minimum number of instances."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of instances."
  type        = number
}

variable "cpu_target_utilization" {
  description = "Average CPU utilisation the Auto Scaling group tracks."
  type        = number
}

variable "db_engine_version" {
  description = "MySQL engine version."
  type        = string
}

variable "db_instance_class" {
  description = "Graviton RDS instance class."
  type        = string
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
}

variable "db_multi_az" {
  description = "Synchronous standby in a second AZ."
  type        = bool
}

variable "db_backup_retention_days" {
  description = "Automated backup retention."
  type        = number
}

variable "db_deletion_protection" {
  description = "Block database deletion."
  type        = bool
}

variable "db_final_snapshot" {
  description = "Take a final snapshot when the database is deleted."
  type        = bool
}

variable "db_performance_insights" {
  description = "Enable Performance Insights (not available on the smallest classes)."
  type        = bool
}

variable "efs_backup" {
  description = "Enable AWS Backup for the file system."
  type        = bool
}

variable "enable_waf" {
  description = "Attach AWS WAF with managed rule groups to the load balancer."
  type        = bool
}

variable "waf_rate_limit_per_5_minutes" {
  description = "Requests per client IP per 5 minutes before WAF blocks."
  type        = number
}

variable "alb_deletion_protection" {
  description = "Block load balancer deletion."
  type        = bool
}

variable "alb_log_retention_in_days" {
  description = "Load balancer access log retention."
  type        = number
}

variable "force_destroy_log_bucket" {
  description = "Allow deleting the access log bucket while it still has logs."
  type        = bool
}

variable "log_retention_in_days" {
  description = "Retention for application, database and WAF logs."
  type        = number
}

variable "alert_email" {
  description = "Email subscribed to alarm notifications."
  type        = string
  sensitive   = true
}
