#----------------------------------#
# Free-tier Environment Configuration #
#----------------------------------#

environment = "free-tier"
project_name = "free-tier-projects"

#---------#
# IAM Users #
#---------#

iam_users = {
  opentofu = {
    description = "Infrastructure automation"
  }
  svc_cheapass = {
    description = "Cost tracking service"
  }
}

create_access_keys = ["opentofu", "svc_cheapass"]

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
  "ghost" = {
    vpc_cidr             = "10.0.0.0/16"
    availability_zones   = ["us-east-2a", "us-east-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
    enable_nat_gateways  = false  # Set to true if private subnets need internet (costs ~$64/month for 2 NATs)
  }
}

#---------------#
# Web Servers (EC2) #
#---------------#

web_servers = {
  "ghost" = {
    instance_type      = "t3.micro"
    root_volume_size   = 30
    root_volume_type   = "gp3"
    key_name           = "ghost-web"  # SSH key pair
    eip_allocation     = true   # Enable EIP (FREE when attached)
    monitoring_enabled = true
    domain_name        = "surfingclouds.io"
    zone_key           = "primary"
    network_key        = "ghost"
  }
}

#-----------#
# Databases (RDS) #
#-----------#

databases = {
  "ghost" = {
    engine               = "mysql"
    engine_version       = "8.0"
    instance_class       = "db.t3.micro"
    allocated_storage    = 20
    storage_type         = "gp3"
    db_name              = "ghostdb"
    # username & password now read from Vault (see vault.tf)
    username             = "placeholder"   # Overridden by Vault data source
    password             = "placeholder"   # Overridden by Vault data source
    port                 = 3306
    backup_retention_days = 1  # Free tier max (was 7, causes FreeTierRestrictionError)
    multi_az             = false
    skip_final_snapshot  = false
    network_key          = "ghost"
  }
}

#---------#
# Storage (S3) #
#---------#

#storage_buckets = {
#  "ghost" = {
#    bucket_suffix           = "backups"
#    versioning_enabled      = true
#    server_side_encryption  = true
#    block_public_access     = true
#    lifecycle_rules = [
#      {
#        id                         = "archive-old-backups"
#        status                     = "Enabled"
#        expiration_days            = 30
#        noncurrent_expiration_days = 7
#      }
#    ]
#  }
#}

#---------#
# DNS Records #
#---------#

dns_records = {
  "ghost" = {
    zone_key = "primary"
    records = {
      "surfingclouds.io" = {
        type   = "A"           # A records automatically use web_server public IP
        ttl    = 300
        values = []            # Empty: will be populated from web_server IP
      }
      "www.surfingclouds.io" = {
        type   = "CNAME"
        ttl    = 300
        values = ["surfingclouds.io"]
      }
    }
  }
}
