output "instance_id" {
  value       = aws_instance.main.id
  description = "Instance ID"
}

output "private_ip" {
  value       = aws_instance.main.private_ip
  description = "Private IP address"
}

output "public_ip" {
  value       = var.eip_allocation ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
  description = "Public IP address (EIP if allocated)"
}

output "primary_network_interface_id" {
  value       = aws_instance.main.primary_network_interface_id
  description = "Primary network interface ID"
}

output "security_group_id" {
  value       = var.security_group_id
  description = "Security group ID"
}
