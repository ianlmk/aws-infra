# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.name}-dbsg"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.name}-dbsg"
    }
  )
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project}-${var.name}"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = var.password
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  multi_az                = var.multi_az

  copy_tags_to_snapshot = true
  deletion_protection   = true
  skip_final_snapshot   = var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = [
    var.engine == "mysql" ? "error" : "postgresql"
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.name}"
    }
  )

  lifecycle {
    ignore_changes = [password]
  }
}
