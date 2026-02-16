# Free-tier environment configuration
# This file auto-loads (*.auto.tfvars pattern)
# Don't commit secrets here; use state or environment variables

environment = "free-tier"
project_name = "ghost"

# IAM Users
iam_users = {
  opentofu = {
    description = "Infrastructure automation user"
  }
}

# Additional policies (default policies are in locals.tf)
# user_policies = {} # Extend with environment-specific policies if needed

# Create access keys for these users
create_access_keys = ["opentofu"]

# Common tags
common_tags = {
  Environment = "free-tier"
  ManagedBy   = "opentofu"
  IaC         = "true"
  Project     = "ghost"
}
