#---------#
# Vault Integration #
#---------#

variable "vault_token" {
  description = "Vault authentication token (set via TF_VAR_vault_token)"
  type        = string
  sensitive   = true
  # No default - must be set via environment variable
}

#---------#
# AWS Core #
#---------#

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "free-tier"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "free-tier-projects"
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "free-tier"
    ManagedBy   = "opentofu"
    IaC         = "true"
  }
}

#-----------#
# IAM Module #
#-----------#

variable "iam_users" {
  description = "IAM users to create"
  type = map(object({
    description = string
  }))
  default = {}
}

variable "user_policies" {
  description = "Policies for IAM users"
  type = map(object({
    user        = string
    policy_name = string
    policy      = string
  }))
  default = {}
}

variable "create_access_keys" {
  description = "Users to create access keys for"
  type        = list(string)
  default     = []
}

#--------------------#
# Route53 Module #
#--------------------#

variable "route53_zones" {
  description = "Route53 public hosted zones to create"
  type = map(object({
    domain_name = string
    comment     = optional(string, "")
  }))
  default = {}
}

#---------#
# Networks #
#---------#

variable "networks" {
  description = "Network configurations (VPC + Security Groups) per application"
  type = map(object({
    vpc_cidr             = optional(string, "10.0.0.0/16")
    availability_zones   = optional(list(string), ["us-east-2a", "us-east-2b"])
    public_subnet_cidrs  = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24"])
    private_subnet_cidrs = optional(list(string), ["10.0.11.0/24", "10.0.12.0/24"])
    enable_nat_gateways  = optional(bool, false)  # Set to true only if needed (costs $32/month each)
  }))
  default = {}
}

#-----------#
# Web Servers #
#-----------#

variable "web_servers" {
  description = "Web server configurations per application"
  type = map(object({
    instance_type      = optional(string, "t3.micro")
    root_volume_size   = optional(number, 30)
    root_volume_type   = optional(string, "gp3")
    eip_allocation     = optional(bool, false)  # Set to true only if you need static IP (costs $3.50/month if unattached)
    monitoring_enabled = optional(bool, true)
    domain_name        = string
    zone_key           = optional(string, "primary")
    # References
    network_key = optional(string)  # Links to networks[network_key]
  }))
  default = {}
}

#-----------#
# Databases #
#-----------#

variable "databases" {
  description = "Database configurations per application"
  type = map(object({
    engine               = optional(string, "mysql")
    engine_version       = optional(string, "8.0")
    instance_class       = optional(string, "db.t3.micro")
    allocated_storage    = optional(number, 20)
    storage_type         = optional(string, "gp3")
    db_name              = string
    username             = optional(string, "admin")
    password             = optional(string, "placeholder")  # Overridden by Vault data source
    port                 = optional(number, 3306)
    backup_retention_days = optional(number, 7)
    multi_az             = optional(bool, false)
    skip_final_snapshot  = optional(bool, false)
    # References
    network_key = optional(string)  # Links to networks[network_key]
  }))
  default = {}
}

#---------#
# Storage #
#---------#

variable "storage_buckets" {
  description = "S3 bucket configurations per application"
  type = map(object({
    bucket_suffix           = optional(string, "backups")
    versioning_enabled      = optional(bool, true)
    server_side_encryption  = optional(bool, true)
    block_public_access     = optional(bool, true)
    lifecycle_rules = optional(list(object({
      id                         = string
      status                     = string
      expiration_days            = optional(number)
      noncurrent_expiration_days = optional(number)
    })), [])
  }))
  default = {}
}

#----------#
# DNS #
#----------#

variable "dns_records" {
  description = "Route53 DNS record configurations"
  type = map(object({
    zone_key = optional(string, "primary")
    records = map(object({
      type    = string                    # A, CNAME, MX, etc.
      ttl     = optional(number, 300)
      values  = optional(list(string), [])  # For static records
      # web_server_key = optional(string)  # For dynamic IP from web_server
    }))
  }))
  default = {}
}
