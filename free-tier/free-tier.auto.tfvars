#----------------------------------#
# Free-tier Network Scaffold #
#----------------------------------#

# This configuration deploys the shared network infrastructure (VPC, subnets, security groups)
# Applications (WordPress, Ghost, etc.) are deployed in separate -infra/ directories
# that reference outputs from this scaffold.

environment = "free-tier"

#--------------------#
# Route53 Hosted Zones #
#--------------------#

route53_zones = {
  primary = {
    domain_name = "surfingclouds.io"
    comment     = "Primary domain for applications"
  }
}

common_tags = {
  Environment = "free-tier"
  ManagedBy   = "opentofu"
  IaC         = "true"
}

#-----------#
# Networks (VPC + Security Groups) #
#-----------#

networks = {
  "default" = {
    vpc_cidr             = "10.0.0.0/16"
    availability_zones   = ["us-east-2a", "us-east-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
    enable_nat_gateways  = false  # Costs $32/month each if enabled - set to true only if private subnets need internet
  }
}

# Notes:
# - Public subnets: For EC2 instances (web servers)
# - Private subnets: For RDS databases
# - Security groups: Preconfigured for web, app, database tiers
# - NAT Gateways: NOT enabled by default (free tier). Only enable if private instances need outbound internet.
