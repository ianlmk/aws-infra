output "endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS endpoint (host:port)"
}

output "address" {
  value       = aws_db_instance.main.address
  description = "RDS host address"
}

output "port" {
  value       = aws_db_instance.main.port
  description = "Database port"
}

output "db_name" {
  value       = aws_db_instance.main.db_name
  description = "Initial database name"
}

output "username" {
  value       = aws_db_instance.main.username
  description = "Master username"
  sensitive   = true
}

output "resource_id" {
  value       = aws_db_instance.main.resource_id
  description = "RDS resource ID"
}

output "arn" {
  value       = aws_db_instance.main.arn
  description = "RDS instance ARN"
}
