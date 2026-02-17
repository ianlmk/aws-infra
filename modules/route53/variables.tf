variable "zones" {
  description = "Route53 public hosted zones to create"
  type = map(object({
    domain_name = string
    comment     = optional(string, "")
  }))
  default = {}
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
