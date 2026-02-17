variable "project" {
  description = "Project name"
  type        = string
}

variable "name" {
  description = "Instance name (e.g., ghost, app)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t3.micro, t3.small)"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "user_data" {
  description = "User data script (base64 encoded)"
  type        = string
  default     = ""
}

variable "ami" {
  description = "AMI ID (default: latest Ubuntu 22.04 LTS)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "monitoring_enabled" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "eip_allocation" {
  description = "Allocate and associate an Elastic IP"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "SSH key pair name (must exist in AWS)"
  type        = string
  default     = ""
}
