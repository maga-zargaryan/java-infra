data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# Contract published by infra-bootstrap, platform-infra and java-ami.
locals {
  platform_parameters = toset([
    "vpc_id",
    "public_subnet_ids",
    "app_subnet_ids",
    "db_subnet_group_name",
    "endpoint_sg_id",
    "s3_prefix_list_id",
    "kms_key_arn",
    "acm_certificate_arn",
    "domain_name",
    "route53_zone_id",
  ])
}

data "aws_ssm_parameter" "platform" {
  for_each = local.platform_parameters

  name = "/java-platform/${var.environment}/${each.value}"
}

data "aws_ssm_parameter" "artifacts_bucket" {
  name = "/java-platform/artifacts_bucket"
}

data "aws_ssm_parameter" "boundary_arn" {
  name = "/java-platform/boundary_arn"
}

data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter
}

locals {
  name       = "java-workload-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  platform = { for k, p in data.aws_ssm_parameter.platform : k => p.insecure_value }

  vpc_id            = local.platform.vpc_id
  public_subnet_ids = split(",", local.platform.public_subnet_ids)
  app_subnet_ids    = split(",", local.platform.app_subnet_ids)
  kms_key_arn       = local.platform.kms_key_arn
  domain_name       = local.platform.domain_name
  artifacts_bucket  = data.aws_ssm_parameter.artifacts_bucket.insecure_value
  boundary_arn      = data.aws_ssm_parameter.boundary_arn.insecure_value
  ami_id            = data.aws_ssm_parameter.ami.insecure_value
}
