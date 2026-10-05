data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name                 = "${local.name}-app"
  description          = "Java application instances (${var.environment})"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume.json
  permissions_boundary = local.boundary_arn
}

resource "aws_iam_role_policy_attachment" "app_managed" {
  for_each = toset([
    "AmazonSSMManagedInstanceCore",
    "CloudWatchAgentServerPolicy",
  ])

  role       = aws_iam_role.app.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ReadReleaseArtifacts"
    actions   = ["s3:GetObject"]
    resources = ["arn:${local.partition}:s3:::${local.artifacts_bucket}/java-app/*"]
  }

  statement {
    sid       = "ReadDatabaseSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_db_instance.this.master_user_secret[0].secret_arn]
  }

  statement {
    sid       = "DecryptDatabaseSecret"
    actions   = ["kms:Decrypt"]
    resources = [local.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${local.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "MountSharedStorage"
    actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    resources = [aws_efs_file_system.this.arn]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.app.arn]
    }
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "application"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app"
  role = aws_iam_role.app.name
}

locals {
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region              = local.region
    environment         = var.environment
    app_version         = var.app_version
    app_port            = var.app_port
    artifacts_bucket    = local.artifacts_bucket
    efs_id              = aws_efs_file_system.this.id
    efs_access_point_id = aws_efs_access_point.app.id
    db_host             = aws_db_instance.this.address
    db_port             = aws_db_instance.this.port
    db_name             = aws_db_instance.this.db_name
    db_secret_arn       = aws_db_instance.this.master_user_secret[0].secret_arn
    log_group_name      = aws_cloudwatch_log_group.app.name
    java_opts           = var.java_opts
  })
}

resource "aws_launch_template" "app" {
  name                   = "${local.name}-app"
  description            = "Java application ${var.app_version} on ${local.ami_id}"
  image_id               = local.ami_id
  instance_type          = var.instance_type
  ebs_optimized          = true
  update_default_version = true
  user_data              = base64encode(local.user_data)
  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = local.kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app", AppVersion = var.app_version }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${local.name}-app"
  vpc_zone_identifier       = local.app_subnet_ids
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_min_size
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 120
  target_group_arns         = [aws_lb_target_group.app.arn]

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # A new AMI or app_version creates a launch template version and rolls the
  # fleet: new instances must pass ELB health checks before old ones go.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 120
      skip_matching          = true
      auto_rollback          = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy.app,
    aws_iam_role_policy_attachment.app_managed,
    aws_efs_mount_target.this,
    aws_efs_file_system_policy.this,
  ]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.cpu_target_utilization

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
