resource "aws_cloudwatch_log_group" "app" {
  name              = "/java-workload/${var.environment}/app"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = local.kms_key_arn
}

resource "aws_sns_topic" "alarms" {
  name              = "${local.name}-alarms"
  kms_master_key_id = local.kms_key_arn
}

resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alb_dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  target_dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarms = {
    alb-5xx = {
      description = "Load balancer returned 5xx responses"
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_ELB_5XX_Count"
      statistic   = "Sum"
      threshold   = 10
      operator    = "GreaterThanOrEqualToThreshold"
      periods     = 1
      dimensions  = local.alb_dimensions
    }
    target-5xx = {
      description = "Application returned 5xx responses"
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_Target_5XX_Count"
      statistic   = "Sum"
      threshold   = 10
      operator    = "GreaterThanOrEqualToThreshold"
      periods     = 1
      dimensions  = local.target_dimensions
    }
    unhealthy-hosts = {
      description = "Application instances failing health checks"
      namespace   = "AWS/ApplicationELB"
      metric      = "UnHealthyHostCount"
      statistic   = "Maximum"
      threshold   = 0
      operator    = "GreaterThanThreshold"
      periods     = 3
      dimensions  = local.target_dimensions
    }
    target-latency = {
      description = "Average application response time above 1 second"
      namespace   = "AWS/ApplicationELB"
      metric      = "TargetResponseTime"
      statistic   = "Average"
      threshold   = 1
      operator    = "GreaterThanThreshold"
      periods     = 3
      dimensions  = local.target_dimensions
    }
    db-cpu = {
      description = "Database CPU above 80%"
      namespace   = "AWS/RDS"
      metric      = "CPUUtilization"
      statistic   = "Average"
      threshold   = 80
      operator    = "GreaterThanThreshold"
      periods     = 3
      dimensions  = { DBInstanceIdentifier = aws_db_instance.this.identifier }
    }
    db-free-storage = {
      description = "Database free storage below 2 GiB"
      namespace   = "AWS/RDS"
      metric      = "FreeStorageSpace"
      statistic   = "Minimum"
      threshold   = 2147483648
      operator    = "LessThanThreshold"
      periods     = 1
      dimensions  = { DBInstanceIdentifier = aws_db_instance.this.identifier }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  dimensions          = each.value.dimensions
  period              = 300
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}
