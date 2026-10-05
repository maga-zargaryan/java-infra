aws_region        = "eu-west-1"
environment       = "dev"
ami_ssm_parameter = "/imagebuilder/java-platform/java-base"

# alert_email comes from the ALERT_EMAIL environment secret (TF_VAR_alert_email).

# Application release (s3://<artifacts>/java-app/<app_version>/app.jar)
app_version       = "0.1.0"
app_port          = 8080
health_check_path = "/health"
java_opts         = "-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"

# Compute (Graviton)
instance_type          = "t4g.small"
root_volume_size       = 20
asg_min_size           = 1
asg_max_size           = 2
cpu_target_utilization = 50

# Database: single-AZ, short backups, disposable
db_engine_version        = "8.4"
db_instance_class        = "db.t4g.micro"
db_name                  = "app"
db_allocated_storage     = 20
db_max_allocated_storage = 50
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false
db_final_snapshot        = false
db_performance_insights  = false

# Storage, edge, observability
efs_backup                   = false
enable_waf                   = false
waf_rate_limit_per_5_minutes = 2000
alb_deletion_protection      = false
alb_log_retention_in_days    = 30
force_destroy_log_bucket     = true
log_retention_in_days        = 30
