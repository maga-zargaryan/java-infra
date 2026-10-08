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
  # The baked boot-time configurator reads this environment's settings.
  statement {
    sid       = "ReadRuntimeSettings"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter/java-platform/${var.environment}/app/*"]
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

# The AMI carries the application release; read its version for tags.
data "aws_ami" "app" {
  owners = ["self"]

  filter {
    name   = "image-id"
    values = [local.ami_id]
  }

  lifecycle {
    postcondition {
      condition     = lookup(self.tags, "Image", "") == "java-app"
      error_message = "ami_id must be an app AMI built by java-ami (tag Image=java-app)."
    }
  }
}

# Marks the AMI as in use so the java-ami lifecycle policy never deletes it.
resource "aws_ec2_tag" "ami_in_use" {
  resource_id = local.ami_id
  key         = "InUse-${var.environment}"
  value       = "true"
}

locals {
  app_version = lookup(data.aws_ami.app.tags, "AppVersion", "unknown")
  ami_commit  = lookup(data.aws_ami.app.tags, "GitCommit", "unknown")
}

resource "aws_launch_template" "app" {
  name                   = "${local.name}-app"
  description            = "Java application ${local.app_version} (${local.ami_id})"
  image_id               = local.ami_id
  instance_type          = var.instance_type
  ebs_optimized          = true
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    # The boot-time configurator reads the Environment tag from instance metadata.
    instance_metadata_tags = "enabled"
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
    tags          = { Name = "${local.name}-app", Environment = var.environment, AppVersion = local.app_version, AmiGitCommit = local.ami_commit }
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
  # Creating or resizing the group succeeds only once this many instances pass ELB health checks.
  wait_for_elb_capacity = var.asg_min_size

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

  # A new AMI (which carries the app release) creates a launch template version and rolls the
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
    aws_ssm_parameter.runtime,
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
