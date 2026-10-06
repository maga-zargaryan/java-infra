aws_region  = "eu-west-1"
environment = "prod"
# Exact app AMI (no "latest"). Promote by copying the AMI ID dev runs.
# Placeholder until the first app AMI is built: plans fail with a clear message until it is set.
ami_id = "ami-SET-AFTER-FIRST-BUILD"

# alert_email comes from the ALERT_EMAIL environment secret (TF_VAR_alert_email).

# The application release comes from the AMI (java-ami app_version).
app_port          = 8080
health_check_path = "/health"
java_opts         = "-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"

# Compute (Graviton): at least one instance per AZ
instance_type          = "m7g.large"
root_volume_size       = 20
asg_min_size           = 2
asg_max_size           = 4
cpu_target_utilization = 50

# Database: Multi-AZ, protected, recoverable
db_engine_version        = "8.4"
db_instance_class        = "db.t4g.large"
db_name                  = "app"
db_allocated_storage     = 50
db_max_allocated_storage = 200
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true
db_final_snapshot        = true
db_performance_insights  = true

# Storage, edge, observability
efs_backup                   = true
enable_waf                   = true
waf_rate_limit_per_5_minutes = 2000
alb_deletion_protection      = true
alb_log_retention_in_days    = 365
force_destroy_log_bucket     = false
log_retention_in_days        = 90
