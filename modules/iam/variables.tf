variable "iam_users" {
  description = "Map of IAM users to create with their descriptions"
  type = map(object({
    description = string
  }))
  default = {}
}

variable "user_policies" {
  description = "Map of policies to attach to users"
  type = map(object({
    user        = string
    policy_name = string
    policy      = string
  }))
  default = {}
}

variable "create_access_keys" {
  description = "List of users to create access keys for"
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
