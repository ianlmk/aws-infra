# ===== VPC Outputs =====
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr
  description = "VPC CIDR block"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "List of public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "List of private subnet IDs"
}

output "public_subnet_cidrs" {
  value       = module.vpc.public_subnet_cidrs
  description = "List of public subnet CIDR blocks"
}

output "private_subnet_cidrs" {
  value       = module.vpc.private_subnet_cidrs
  description = "List of private subnet CIDR blocks"
}

output "igw_id" {
  value       = module.vpc.igw_id
  description = "Internet Gateway ID"
}

output "nat_gateway_ids" {
  value       = module.vpc.nat_gateway_ids
  description = "List of NAT Gateway IDs"
}

output "nat_eips" {
  value       = module.vpc.nat_eips
  description = "List of Elastic IPs for NAT Gateways"
}

# ===== Security Groups Outputs =====
output "web_sg_id" {
  value       = module.security_groups.web_sg_id
  description = "Web tier security group ID"
}

output "app_sg_id" {
  value       = module.security_groups.app_sg_id
  description = "App tier security group ID"
}

output "database_sg_id" {
  value       = module.security_groups.database_sg_id
  description = "Database tier security group ID"
}
