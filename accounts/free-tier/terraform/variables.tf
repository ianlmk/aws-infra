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
  description = "Project name for tagging (can be overridden per project)"
  type        = string
  default     = "free-tier-projects"
}
