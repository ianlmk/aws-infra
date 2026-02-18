#---------#
# VPC Outputs #
#---------#

output "vpc_id" {
  description = "VPC ID (for applications to reference)"
  value       = {
    for key, network in module.network :
    key => network.vpc_id
  }
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = {
    for key, network in module.network :
    key => network.vpc_cidr
  }
}

#-----------#
# Subnet Outputs #
#-----------#

output "public_subnet_ids" {
  description = "Public subnet IDs (for web servers)"
  value       = {
    for key, network in module.network :
    key => network.public_subnet_ids
  }
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for databases, private instances)"
  value       = {
    for key, network in module.network :
    key => network.private_subnet_ids
  }
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  value       = {
    for key, network in module.network :
    key => network.public_subnet_cidrs
  }
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  value       = {
    for key, network in module.network :
    key => network.private_subnet_cidrs
  }
}

#---------------------#
# Security Group Outputs #
#---------------------#

output "web_security_group_ids" {
  description = "Web tier security group IDs (for application servers)"
  value       = {
    for key, network in module.network :
    key => network.web_sg_id
  }
}

output "app_security_group_ids" {
  description = "App tier security group IDs (for application servers)"
  value       = {
    for key, network in module.network :
    key => network.app_sg_id
  }
}

output "database_security_group_ids" {
  description = "Database tier security group IDs (for RDS)"
  value       = {
    for key, network in module.network :
    key => network.database_sg_id
  }
}

#-----------#
# Route53 Outputs #
#-----------#

output "route53_zone_ids" {
  description = "Route53 zone IDs (for DNS records)"
  value       = {
    for key, zone in module.route53.zones :
    key => zone.zone_id
  }
}

output "route53_zone_nameservers" {
  description = "Route53 nameservers (for domain delegation)"
  value       = {
    for key, zone in module.route53.zones :
    key => zone.name_servers
  }
}

#---------#
# Setup Instructions #
#---------#

output "setup_instructions" {
  description = "Instructions for deploying applications"
  value       = <<-EOF
✓ Network infrastructure deployed!

This scaffold provides the foundation for applications.

Next steps:

1. Deploy WordPress application:
   cd ../wordpress-infra
   cp terraform.tfvars.example terraform.tfvars
   terraform init
   terraform apply

2. Deploy Ghost application:
   cd ../ghost-infra
   cp terraform.tfvars.example terraform.tfvars
   terraform init
   terraform apply

3. Each application will:
   - Create its own EC2 instance (or use shared network)
   - Create its own RDS database
   - Create its own S3 bucket
   - Register DNS records in Route53

Network Architecture:
- VPC CIDR: See vpc_cidr output
- Public subnets: For web servers (EC2)
- Private subnets: For databases (RDS)
- Security groups: Preconfigured for web, app, database tiers

To tear down applications independently:
  cd wordpress-infra && terraform destroy
  cd ghost-infra && terraform destroy

To tear down the entire network scaffold:
  cd free-tier && terraform destroy  (removes VPC, subnets, Route53)

EOF
}
