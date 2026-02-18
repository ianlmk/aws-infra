#------------------#
# Ghost Configuration #
#------------------#

# Application name (generic - no CMS/project identifiers)
app_name = "app1"

# Ghost Blog URL
ghost_url = "https://surfingclouds.io"

# Ghost Admin Email
ghost_admin_email = "admin@surfingclouds.io"

# Ghost Mail Configuration
ghost_mail_from = "noreply@surfingclouds.io"
ghost_mail_service = "Direct"

# Ghost & Node.js Versions
ghost_version = "latest"
node_version = "18"

#-----------#
# Database  #
#-----------#

# MySQL Configuration
mysql_version = "8.0.35"

# RDS Instance Settings
rds_instance_class    = "db.t3.micro"  # Free tier eligible
rds_allocated_storage = 20             # GB

# Backup Configuration
backup_retention_days = 7
backup_window         = "02:00-03:00"  # UTC
maintenance_window    = "sun:03:00-sun:04:00"

# Advanced Options (free tier defaults)
skip_final_snapshot             = true   # Set to false in production
enable_performance_insights     = false  # Additional cost
performance_insights_retention_days = 7
monitoring_interval             = 60    # seconds
enable_deletion_protection      = false # Set to true in production

#----------#
# EC2      #
#----------#

# Instance Settings
ec2_instance_type      = "t3.micro"  # Free tier eligible
ec2_root_volume_size   = 30          # GB
ec2_root_volume_type   = "gp3"

# SSH Configuration
ssh_private_key_path = "~/.ssh/app1-web-key"

#--------#
# SSL    #
#--------#

enable_ssl = true

#-----------#
# Deployment #
#-----------#

deploy_ghost = true
ansible_verbosity = 0

# Note: AWS region and Vault token come from environment variables
# export TF_VAR_vault_token=$(vault print token)
# export TF_VAR_aws_region=us-east-2
