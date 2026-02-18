#------------------#
# Network Scaffold #
#------------------#

# Single unified network infrastructure (shared by all applications)

module "network" {
  for_each = var.networks

  source = "../modules/network"

  project               = each.key
  environment           = var.environment
  vpc_cidr              = each.value.vpc_cidr
  availability_zones    = each.value.availability_zones
  public_subnet_cidrs   = each.value.public_subnet_cidrs
  private_subnet_cidrs  = each.value.private_subnet_cidrs
  tags                  = local.common_tags
}

#---------#
# Route53 #
#---------#

module "route53" {
  source = "../modules/route53"

  zones       = var.route53_zones
  environment = var.environment
  tags        = local.common_tags
}
