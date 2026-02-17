# Network module: composes VPC + Security Groups
# VPC is a prerequisite of security groups
# Network is a prerequisite of everything else (compute, database, storage, DNS)

# VPC & Subnets
module "vpc" {
  source = "../vpc_network"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateways  = var.enable_nat_gateways
  tags                 = var.tags
}

# Security Groups (depends on VPC)
module "security_groups" {
  source = "../security_groups"

  project = var.project
  vpc_id  = module.vpc.vpc_id
  tags    = var.tags
}
