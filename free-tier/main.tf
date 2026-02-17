#------------------#
# Root Orchestration #
#------------------#

module "iam" {
  source = "../modules/iam"

  environment        = var.environment
  iam_users          = var.iam_users
  user_policies      = merge(var.user_policies, local.policies)
  create_access_keys = var.create_access_keys
  tags               = local.common_tags
}

module "route53" {
  source = "../modules/route53"

  zones       = var.route53_zones
  environment = var.environment
  tags        = local.common_tags
}

#---------#
# Networks #
#---------#

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

#-------------#
# Web Servers #
#-----------#

module "web_server" {
  for_each = var.web_servers

  source = "../modules/ec2_compute"

  project            = each.key
  name               = "web"
  instance_type      = each.value.instance_type
  subnet_id          = module.network[each.value.network_key].public_subnet_ids[0]
  security_group_id  = module.network[each.value.network_key].web_sg_id
  root_volume_size   = each.value.root_volume_size
  root_volume_type   = each.value.root_volume_type
  key_name           = lookup(each.value, "key_name", "")
  eip_allocation     = each.value.eip_allocation
  monitoring_enabled = each.value.monitoring_enabled
  tags               = local.common_tags

  # Inject SSH public key via user_data from Vault
  user_data = base64encode(templatefile(
    "${path.module}/user-data.sh",
    { public_key = data.vault_generic_secret.ssh_keys.data["public_key"] }
  ))

  # Ensure prerequisites exist before creating instance:
  # 1. aws_key_pair.ghost_web - SSH key pair registered in AWS
  # 2. data.vault_generic_secret.ssh_keys - SSH secret loaded from Vault
  depends_on = [
    aws_key_pair.ghost_web,
    data.vault_generic_secret.ssh_keys
  ]
}

#-----------#
# Databases #
#-----------#

module "database" {
  for_each = var.databases

  source = "../modules/rds_database"

  project            = each.key
  name               = "mysql"
  engine             = each.value.engine
  engine_version     = each.value.engine_version
  instance_class     = each.value.instance_class
  allocated_storage  = each.value.allocated_storage
  storage_type       = each.value.storage_type
  db_name            = each.value.db_name
  username           = data.vault_generic_secret.rds_creds.data["username"]  # From Vault
  password           = data.vault_generic_secret.rds_creds.data["password"]  # From Vault
  port               = each.value.port
  subnet_ids         = module.network[each.value.network_key].private_subnet_ids
  security_group_id  = module.network[each.value.network_key].database_sg_id
  backup_retention_days = each.value.backup_retention_days
  multi_az           = each.value.multi_az
  skip_final_snapshot = each.value.skip_final_snapshot
  tags               = local.common_tags

  # Ensure Vault secrets are loaded first
  depends_on = [data.vault_generic_secret.rds_creds]
}

#---------#
# Storage #
#---------#

module "storage" {
  for_each = var.storage_buckets

  source = "../modules/s3"

  project                = each.key
  bucket_name            = each.value.bucket_suffix
  versioning_enabled     = each.value.versioning_enabled
  server_side_encryption = each.value.server_side_encryption
  block_public_access    = each.value.block_public_access
  lifecycle_rules        = each.value.lifecycle_rules
  tags                   = local.common_tags
}

#----------#
# DNS #
#----------#

locals {
  # Flatten dns_records structure: app/record -> config
  dns_records_flat = merge([
    for app_key, app_records in var.dns_records : {
      for record_name, record_config in app_records.records : 
        "${app_key}_${record_name}" => merge(
          record_config,
          { zone_key = app_records.zone_key, name = record_name }
        )
    }
  ]...)
}

#------#
# DNS #
#------#

resource "aws_route53_record" "web" {
  for_each = {
    for k, v in local.dns_records_flat :
    k => v
    # Only create DNS records if web_servers exist OR if it's not an A record
    if length(var.web_servers) > 0 || v.type != "A"
  }

  zone_id = module.route53.zones[each.value.zone_key].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  
  # Dynamically set records: use web_server public IP for A records
  records = each.value.type == "A" ? [module.web_server[split("_", each.key)[0]].public_ip] : each.value.values
}
