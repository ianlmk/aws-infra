variable "admin_profile" {
  description = "AWS profile for admin user running bootstrap (e.g., 'default' for player1)"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "infra_user_name" {
  description = "IAM username for infrastructure automation (Terraform/OpenTofu)"
  type        = string
  default     = "opentofu"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
  default     = "tfstate-ghost-p1"
  
  validation {
    condition     = can(regex("^tfstate-[a-z0-9-]+$", var.state_bucket_name))
    error_message = "State bucket name must start with 'tfstate-' and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}
