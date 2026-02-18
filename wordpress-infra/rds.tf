# RDS MySQL Database for WordPress

# DB Subnet Group
resource "aws_db_subnet_group" "wordpress" {
  name       = "${local.app_name}-wordpress-db-subnet-group"
  subnet_ids = local.private_subnet_ids

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-db-subnet-group" }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds_wordpress" {
  name        = "${local.app_name}-wordpress-db-sg"
  description = "Security group for WordPress RDS MySQL"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [data.aws_security_group.app.id]
    description     = "MySQL from app servers"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-db-sg" }
  )
}

# RDS MySQL Instance
resource "aws_db_instance" "wordpress" {
  identifier     = "${local.app_name}-wordpress-mysql"
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = local.rds_instance_class

  allocated_storage = local.rds_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = local.wordpress_db_name
  username = local.wordpress_db_user
  password = local.wordpress_db_password

  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds_wordpress.id]

  # Backup and maintenance
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  skip_final_snapshot     = var.skip_final_snapshot  # Set to false in production!

  # Performance Insights (free tier eligible)
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_retention  = var.performance_insights_retention_days
  performance_insights_kms_key_id = null

  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Parameters
  parameter_group_name = aws_db_parameter_group.wordpress.name

  # Multi-AZ (free tier: avoid this, costs money)
  multi_az = false

  # Public accessibility (should be false for security)
  publicly_accessible = false

  # Deletion protection
  deletion_protection = var.enable_deletion_protection

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-mysql" }
  )

  depends_on = [aws_iam_role_policy.rds_monitoring]
}

# RDS Parameter Group
resource "aws_db_parameter_group" "wordpress" {
  name   = "${local.app_name}-wordpress-mysql-params"
  family = "mysql${split(".", var.mysql_version)[0]}.${split(".", var.mysql_version)[1]}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-mysql-params" }
  )
}

# IAM Role for RDS Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.app_name}-wordpress-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.wordpress_tags
}

# Attach RDS Monitoring Policy
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_iam_role_policy" "rds_monitoring" {
  name   = "${local.app_name}-wordpress-rds-monitoring-policy"
  role   = aws_iam_role.rds_monitoring.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
