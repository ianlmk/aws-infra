output "web_sg_id" {
  value       = aws_security_group.web.id
  description = "Web tier security group ID"
}

output "app_sg_id" {
  value       = aws_security_group.app.id
  description = "App tier security group ID"
}

output "database_sg_id" {
  value       = aws_security_group.database.id
  description = "Database tier security group ID"
}
