# Task 2 is a separate MySQL security demonstration.
# EverShop continues to use PostgreSQL. This stack does not attach to the store volume.

resource "aws_vpc" "main" {
  count                = module.guard.resource_count
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  count                   = module.guard.resource_count * 2
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet("10.20.0.0/16", 8, count.index + 10)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private" {
  count  = module.guard.resource_count
  vpc_id = aws_vpc.main[0].id
}

resource "aws_route_table_association" "private" {
  count          = module.guard.resource_count * 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_vpc_endpoint" "s3" {
  count             = module.guard.resource_count
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private[0].id]
}

resource "aws_security_group" "app" {
  count       = module.guard.resource_count
  name        = "cloudcart-app"
  description = "Application instances. No direct internet ingress and no internet egress."
  vpc_id      = aws_vpc.main[0].id
}

resource "aws_security_group" "mysql" {
  count       = module.guard.resource_count
  name        = "cloudcart-mysql"
  description = "MySQL accepts TLS connections from the application security group only."
  vpc_id      = aws_vpc.main[0].id
}

resource "aws_security_group" "endpoints" {
  count       = module.guard.resource_count * (var.enable_interface_endpoints ? 1 : 0)
  name        = "cloudcart-interface-endpoints"
  description = "Interface endpoints for STS and Secrets Manager."
  vpc_id      = aws_vpc.main[0].id
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_app" {
  count                        = module.guard.resource_count
  security_group_id            = aws_security_group.mysql[0].id
  referenced_security_group_id = aws_security_group.app[0].id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL from application instances"
}

resource "aws_vpc_security_group_egress_rule" "app_to_mysql" {
  count                        = module.guard.resource_count
  security_group_id            = aws_security_group.app[0].id
  referenced_security_group_id = aws_security_group.mysql[0].id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL to the database security group"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  count                        = module.guard.resource_count * (var.enable_interface_endpoints ? 1 : 0)
  security_group_id            = aws_security_group.endpoints[0].id
  referenced_security_group_id = aws_security_group.app[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from application instances"
}

resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  count                        = module.guard.resource_count * (var.enable_interface_endpoints ? 1 : 0)
  security_group_id            = aws_security_group.app[0].id
  referenced_security_group_id = aws_security_group.endpoints[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to STS and Secrets Manager endpoints"
}

resource "aws_vpc_security_group_egress_rule" "app_dns" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.app[0].id
  cidr_ipv4         = "${cidrhost(aws_vpc.main[0].cidr_block, 2)}/32"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  description       = "Amazon VPC DNS resolver at the VPC base address plus two"
}

resource "aws_vpc_security_group_egress_rule" "app_dns_tcp" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.app[0].id
  cidr_ipv4         = "${cidrhost(aws_vpc.main[0].cidr_block, 2)}/32"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  description       = "Amazon VPC DNS resolver over TCP"
}

data "aws_prefix_list" "s3" {
  count = module.guard.resource_count

  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.ap-south-1.s3"]
  }
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.app[0].id
  prefix_list_id    = data.aws_prefix_list.s3[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to the S3 gateway endpoint prefix list"
}

resource "aws_db_subnet_group" "mysql" {
  count      = module.guard.resource_count
  name       = "cloudcart-mysql"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_parameter_group" "mysql" {
  count  = module.guard.resource_count
  name   = "cloudcart-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "require_secure_transport"
    value = "1"
  }

  parameter {
    name  = "tls_version"
    value = "TLSv1.2,TLSv1.3"
  }

  parameter {
    name  = "local_infile"
    value = "0"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }
}

resource "aws_db_option_group" "audit" {
  count                = module.guard.resource_count
  name                 = "cloudcart-mysql-audit"
  engine_name          = "mysql"
  major_engine_version = "8.0"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"

    option_settings {
      name  = "SERVER_AUDIT_EVENTS"
      value = "CONNECT,QUERY_DDL,QUERY_DCL"
    }
  }
}

resource "aws_db_instance" "mysql" {
  count                               = module.guard.resource_count
  identifier                          = "cloudcart-mysql"
  engine                              = "mysql"
  engine_version                      = "8.0"
  auto_minor_version_upgrade          = true
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage_gb
  max_allocated_storage               = var.max_allocated_storage_gb
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.database[0].arn
  multi_az                            = true
  publicly_accessible                 = false
  iam_database_authentication_enabled = true
  username                            = "cloudcart_admin"
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = aws_kms_key.database[0].arn
  db_name                             = "cloudcart_security"
  db_subnet_group_name                = aws_db_subnet_group.mysql[0].name
  vpc_security_group_ids              = [aws_security_group.mysql[0].id]
  parameter_group_name                = aws_db_parameter_group.mysql[0].name
  option_group_name                   = aws_db_option_group.audit[0].name
  backup_retention_period             = var.backup_retention_days
  backup_window                       = "18:30-19:00"
  maintenance_window                  = "sun:19:30-sun:20:00"
  copy_tags_to_snapshot               = true
  delete_automated_backups            = true
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "cloudcart-mysql-final"
  enabled_cloudwatch_logs_exports     = ["audit", "error", "slowquery"]
  apply_immediately                   = false

  lifecycle {
    prevent_destroy = true
  }
}

# Private DNS answers sts.ap-south-1.amazonaws.com from inside the VPC.
# It does not answer the legacy global name sts.amazonaws.com.
# Clients must use the regional endpoint (AWS_STS_REGIONAL_ENDPOINTS=regional).
# IAM database tokens are signed locally from instance-metadata credentials.
# This endpoint is for explicit STS calls such as GetCallerIdentity.
# AssumeRole is omitted on purpose.

resource "aws_vpc_endpoint" "sts" {
  count               = module.guard.resource_count * (var.enable_interface_endpoints ? 1 : 0)
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.ap-south-1.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CallerIdentityOnly"
      Effect    = "Allow"
      Principal = "*"
      Action    = "sts:GetCallerIdentity"
      Resource  = "*"
    }]
  })
}

resource "aws_vpc_endpoint" "secretsmanager" {
  count               = module.guard.resource_count * (var.enable_interface_endpoints ? 1 : 0)
  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.ap-south-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CloudCartSecrets"
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
      ]
      Resource = [
        "arn:aws:secretsmanager:ap-south-1:*:secret:rds!db-*",
        "arn:aws:secretsmanager:ap-south-1:*:secret:cloudcart/*",
      ]
    }]
  })
}

data "aws_caller_identity" "current" {
  count = module.guard.resource_count
}

resource "aws_kms_key" "database" {
  count                   = module.guard.resource_count
  description             = "CloudCart MySQL storage and the RDS-managed master secret."
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "database" {
  count         = module.guard.resource_count
  name          = "alias/cloudcart-mysql"
  target_key_id = aws_kms_key.database[0].key_id
}

resource "aws_iam_role" "database_client" {
  count = module.guard.resource_count
  name  = "cloudcart-mysql-client"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "database_client" {
  count = module.guard.resource_count
  name  = "cloudcart-mysql-client"
  role  = aws_iam_role.database_client[0].name
}

resource "aws_iam_role_policy" "database_client" {
  count = module.guard.resource_count
  name  = "cloudcart-mysql-client"
  role  = aws_iam_role.database_client[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConnectAsIamUser"
        Effect   = "Allow"
        Action   = "rds-db:connect"
        Resource = "arn:aws:rds-db:ap-south-1:${data.aws_caller_identity.current[0].account_id}:dbuser:${aws_db_instance.mysql[0].resource_id}/${local.iam_database_user}"
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-mysql-cpu"
  alarm_description   = "MySQL CPU stayed above 80 percent. No notification topic is attached."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mysql[0].identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "storage" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-mysql-free-storage"
  alarm_description   = "Free storage fell below 2 GiB. No notification topic is attached."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mysql[0].identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-mysql-connections"
  alarm_description   = "Database connections stayed above 40. No notification topic is attached."
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.mysql[0].identifier }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 40
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_log_group" "rotation" {
  count             = module.guard.resource_count
  name              = "/cloudcart/mysql/rotation"
  retention_in_days = 14
}

resource "aws_cloudwatch_event_rule" "rotation_failed" {
  count       = module.guard.resource_count
  name        = "cloudcart-mysql-rotation-failed"
  description = "RDS-managed master password rotation failed. AWSCURRENT is left in place."

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS Service Event via CloudTrail"]
    detail = {
      eventName = ["RotationFailed"]
    }
  })
}

resource "aws_cloudwatch_log_resource_policy" "rotation" {
  count       = module.guard.resource_count
  policy_name = "cloudcart-mysql-rotation"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowRotationFailureLogs"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.rotation[0].arn}:*"
    }]
  })
}

resource "aws_cloudwatch_event_target" "rotation_failed" {
  count = module.guard.resource_count
  rule  = aws_cloudwatch_event_rule.rotation_failed[0].name
  arn   = aws_cloudwatch_log_group.rotation[0].arn
}

output "sts_endpoint_id" {
  value = one(aws_vpc_endpoint.sts[*].id)
}

output "secretsmanager_endpoint_id" {
  value = one(aws_vpc_endpoint.secretsmanager[*].id)
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master password. The secret value is not an output."
  value       = one([for instance in aws_db_instance.mysql : instance.master_user_secret[0].secret_arn])
}

output "database_client_role_arn" {
  value = one(aws_iam_role.database_client[*].arn)
}

output "kms_key_arn" {
  value = one(aws_kms_key.database[*].arn)
}
