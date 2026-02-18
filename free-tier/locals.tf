# Computed values and locals for reuse across modules

locals {
  # AWS account and region info
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming convention for resources
  environment = var.environment

  # Common tags with computed values
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "opentofu"
      Scaffold    = "free-tier"  # Indicates this is shared network infrastructure
    }
  )
}
