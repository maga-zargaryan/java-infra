# Traffic chain: internet → ALB → app → (RDS, EFS); app → AWS through VPC endpoints only.

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Public HTTPS entry point"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-alb" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Java application instances"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-app" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "MySQL database"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-db" }
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "EFS mount targets"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-efs" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0" #trivy:ignore:AVD-AWS-0107 public load balancer
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet, redirected to HTTPS"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0" #trivy:ignore:AVD-AWS-0107 public load balancer
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to application instances"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application traffic from the load balancer"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTPS to AWS interface endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = local.platform.endpoint_sg_id
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to S3 through the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = local.platform.s3_prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_efs" {
  security_group_id            = aws_security_group.app.id
  description                  = "NFS to EFS"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.efs.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from application instances"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_app" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from application instances"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.app.id
}
