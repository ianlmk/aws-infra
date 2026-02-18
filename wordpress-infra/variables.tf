variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vault_token" {
  description = "Vault authentication token"
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "Application name (generic: app1, app2)"
  type        = string
  default     = "app1"
}

# WordPress Configuration
variable "wordpress_url" {
  description = "Full URL of WordPress site (e.g., https://yourdomain.com)"
  type        = string
}

variable "wordpress_admin_email" {
  description = "WordPress admin email address"
  type        = string
  default     = "admin@example.com"
}

variable "wordpress_php_version" {
  description = "PHP version (e.g., 8.2)"
  type        = string
  default     = "8.2"
}

variable "wordpress_memory_limit" {
  description = "WordPress PHP memory limit"
  type        = string
  default     = "256M"
}

variable "wordpress_max_upload_size" {
  description = "Maximum upload file size"
  type        = string
  default     = "100M"
}

# RDS Configuration
variable "mysql_version" {
  description = "MySQL version (e.g., 8.0.35)"
  type        = string
  default     = "8.0.35"
}

variable "rds_instance_class" {
  description = "RDS instance class (free tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (false for production)"
  type        = bool
  default     = true
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_retention_days" {
  description = "Performance Insights retention period (7 or 31)"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (0 or 60-3600)"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Enable RDS deletion protection"
  type        = bool
  default     = false
}

# Ansible Configuration
variable "deploy_wordpress" {
  description = "Automatically deploy WordPress via Ansible"
  type        = bool
  default     = true
}

variable "ansible_playbook_path" {
  description = "Path to WordPress Ansible playbook"
  type        = string
  default     = "../../ansible-core/playbooks/deploy-wordpress.yml"
}

variable "ansible_verbosity" {
  description = "Ansible verbosity level (0-4)"
  type        = number
  default     = 0
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/app1-web-key"
}

variable "output_inventory_path" {
  description = "Path to output Ansible inventory file"
  type        = string
  default     = "."
}

# IAM Configuration
variable "attach_iam_instance_profile" {
  description = "Attach IAM instance profile to EC2"
  type        = bool
  default     = true
}

variable "enable_ssm_parameters" {
  description = "Enable AWS Systems Manager parameter access"
  type        = bool
  default     = false
}

# SSL Configuration
variable "enable_ssl" {
  description = "Enable SSL/TLS (Let's Encrypt)"
  type        = bool
  default     = true
}
