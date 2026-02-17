variable "project" {
  description = "Project name"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name (will be prefixed with project)"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "server_side_encryption" {
  description = "Enable server-side encryption (AES256)"
  type        = bool
  default     = true
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for object retention"
  type = list(object({
    id     = string
    status = string
    expiration_days = optional(number)
    noncurrent_expiration_days = optional(number)
  }))
  default = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
