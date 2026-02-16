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

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "free-tier-projects"
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

# IAM Module Variables
variable "iam_users" {
  description = "IAM users to create"
  type = map(object({
    description = string
  }))
  default = {}
}

variable "user_policies" {
  description = "Policies for IAM users"
  type = map(object({
    user        = string
    policy_name = string
    policy      = string
  }))
  default = {}
}

variable "create_access_keys" {
  description = "Users to create access keys for"
  type        = list(string)
  default     = []
}
