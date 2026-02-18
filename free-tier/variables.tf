#---------#
# Vault #
#---------#

variable "vault_token" {
  description = "Vault authentication token (set via TF_VAR_vault_token)"
  type        = string
  sensitive   = true
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

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "free-tier"
    ManagedBy   = "opentofu"
    IaC         = "true"
  }
}

#--------------------#
# Route53 #
#--------------------#

variable "route53_zones" {
  description = "Route53 public hosted zones to create (network scaffold)"
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
  description = "Network configurations (VPC + subnets + security groups)"
  type = map(object({
    vpc_cidr             = optional(string, "10.0.0.0/16")
    availability_zones   = optional(list(string), ["us-east-2a", "us-east-2b"])
    public_subnet_cidrs  = optional(list(string), ["10.0.1.0/24", "10.0.2.0/24"])
    private_subnet_cidrs = optional(list(string), ["10.0.11.0/24", "10.0.12.0/24"])
    enable_nat_gateways  = optional(bool, false)  # Costs money, avoid for free tier
  }))
  default = {}
}
