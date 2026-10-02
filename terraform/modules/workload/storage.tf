resource "aws_efs_file_system" "this" {
  creation_token   = local.name
  encrypted        = true
  kms_key_id       = local.kms_key_arn
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = { Name = local.name }
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.efs_backup ? "ENABLED" : "DISABLED"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = toset(local.app_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# The application sees only /app, always as uid/gid 1001.
resource "aws_efs_access_point" "app" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/app"

    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "0750"
    }
  }

  tags = { Name = "${local.name}-app" }
}

data "aws_iam_policy_document" "efs" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AppThroughAccessPoint"
    actions = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.app.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.app.arn]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy         = data.aws_iam_policy_document.efs.json
}
