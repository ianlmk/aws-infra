#------------------#
# Root Outputs #
#------------------#

output "iam_users" {
  description = "IAM users created by the IAM module"
  value       = module.iam.users
}

output "iam_access_keys" {
  description = "IAM access key IDs (retrieve secrets from state)"
  value       = module.iam.access_keys
}

output "iam_policies" {
  description = "IAM policies created"
  value       = module.iam.policies
}

output "account_info" {
  description = "AWS account and region information"
  value = {
    account_id = local.account_id
    region     = local.region
  }
}

output "iam_access_keys_secret" {
  description = "IAM access key secrets (sensitive - do not log)"
  value       = module.iam.access_keys_secret
  sensitive   = true
}

output "route53_zones" {
  description = "Route53 hosted zones"
  value       = module.route53.zones
}

output "route53_nameservers" {
  description = "Route53 nameservers for domain registrar configuration"
  value       = module.route53.nameservers
}

#---------------------#
# Application Outputs #
#---------------------#

output "networks" {
  description = "Network infrastructure (VPC + subnets + security groups) per application"
  value = {
    for app_key, network_module in module.network :
    app_key => {
      vpc_id              = network_module.vpc_id
      vpc_cidr            = network_module.vpc_cidr
      public_subnets     = network_module.public_subnet_ids
      private_subnets    = network_module.private_subnet_ids
      web_sg_id          = network_module.web_sg_id
      app_sg_id          = network_module.app_sg_id
      database_sg_id     = network_module.database_sg_id
      nat_gateways       = network_module.nat_gateway_ids
    }
  }
}

output "web_servers" {
  description = "Web server details per application"
  value = {
    for app_key, web_module in module.web_server :
    app_key => {
      instance_id = web_module.instance_id
      private_ip  = web_module.private_ip
      public_ip   = web_module.public_ip
    }
  }
}

output "databases" {
  description = "RDS database details per application"
  value = {
    for app_key, db_module in module.database :
    app_key => {
      endpoint   = db_module.endpoint
      address    = db_module.address
      port       = db_module.port
      db_name    = db_module.db_name
      username   = db_module.username
    }
  }
  sensitive = true
}

output "storage" {
  description = "S3 storage bucket details per application"
  value = {
    for app_key, s3_module in module.storage :
    app_key => {
      bucket_id     = s3_module.bucket_id
      bucket_arn    = s3_module.bucket_arn
      bucket_domain = s3_module.bucket_domain_name
    }
  }
}

output "dns_records" {
  description = "Route53 DNS records created"
  value = {
    for record_key, record in aws_route53_record.web :
    record_key => {
      fqdn    = record.fqdn
      name    = record.name
      type    = record.type
      records = record.records
    }
  }
}
