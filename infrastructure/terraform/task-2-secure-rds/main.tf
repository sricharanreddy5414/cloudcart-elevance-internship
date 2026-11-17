# Task 2 is a separate MySQL security demonstration.
# EverShop continues to use PostgreSQL. This stack does not attach to the store volume.

resource "aws_vpc" "main" {
  count                = module.guard.resource_count
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  count             = module.guard.resource_count * 2
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet("10.20.0.0/16", 8, count.index + 10)
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)
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
  description = "Application instances. No direct internet ingress."
  vpc_id      = aws_vpc.main[0].id

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [for subnet in aws_subnet.private : subnet.cidr_block]
  }
}

resource "aws_security_group" "mysql" {
  count       = module.guard.resource_count
  name        = "cloudcart-mysql"
  description = "MySQL accepts TLS connections from the application security group only."
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description     = "MySQL from application instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app[0].id]
  }
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
      value = "CONNECT,QUERY"
    }
  }
}

resource "aws_db_instance" "mysql" {
  count                               = module.guard.resource_count
  identifier                          = "cloudcart-mysql"
  engine                              = "mysql"
  engine_version                      = "8.0"
  instance_class                      = "db.t3.micro"
  allocated_storage                   = 20
  storage_type                        = "gp3"
  storage_encrypted                   = true
  multi_az                            = true
  publicly_accessible                 = false
  iam_database_authentication_enabled = true
  username                            = "cloudcart_admin"
  manage_master_user_password         = true
  db_name                             = "cloudcart_security"
  db_subnet_group_name                = aws_db_subnet_group.mysql[0].name
  vpc_security_group_ids              = [aws_security_group.mysql[0].id]
  parameter_group_name                = aws_db_parameter_group.mysql[0].name
  option_group_name                   = aws_db_option_group.audit[0].name
  backup_retention_period             = 7
  backup_window                       = "18:30-19:00"
  maintenance_window                  = "sun:19:30-sun:20:00"
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "cloudcart-mysql-final"
  enabled_cloudwatch_logs_exports     = ["error", "slowquery"]
  apply_immediately                   = false
}
