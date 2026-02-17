# CMS/App Agnostic Architecture

**Date:** 2026-02-16  
**Status:** ✅ Generic module references live

## What Changed

### Old (Ghost-Specific)
```
Variables:      ghost_enabled, ghost_domain_name, ghost_db_password, etc.
Modules:        ghost_network, ghost_web, ghost_database, ghost_storage
Outputs:        ghost_web_server, ghost_database, etc.
```

### New (App-Agnostic)
```
Variables:      app_enabled, domain_name, db_password, etc.
Modules:        network, web_server, database, storage
Outputs:        app_web_server, app_database, etc.
```

**Result:** Same infrastructure, zero CMS lock-in. Deploy Ghost, WordPress, or custom apps with identical Terraform.

## How to Deploy Any App

### 1. Configure the app stack in `free-tier.auto.tfvars`

```hcl
app_enabled = true          # Turn on infrastructure
app_name = "ghost"          # Change to "wordpress", "app", etc.

# Web server
web_instance_type = "t3.micro"

# DNS
domain_name = "surfingclouds.io"

# Database
db_name = "appdb"
db_username = "admin"
# db_password = "..." # Use environment variable (see below)
```

### 2. Set the database password (never in tfvars!)

```bash
export TF_VAR_db_password="YourSecurePassword123!"
```

### 3. Plan & Deploy

```bash
cd ~/workspace/seldon/aws-infra/free-tier

# Preview changes
AWS_PROFILE=opentofu ~/.local/bin/tofu plan -var="app_enabled=true"

# Deploy
AWS_PROFILE=opentofu ~/.local/bin/tofu apply
```

### 4. Access infrastructure

```bash
# Get web server IP
tofu output app_web_server

# Get database endpoint
tofu output app_database

# Get storage bucket
tofu output app_storage
```

## Adding a Second App (e.g., WordPress)

**Don't duplicate the infrastructure code.** Instead, add variables + modules for app2:

### Step 1: Add app2 variables to `variables.tf`

```hcl
variable "app2_enabled" {
  description = "Enable app2 stack"
  type        = bool
  default     = false
}

variable "app2_name" {
  description = "App2 name"
  type        = string
  default     = "wordpress"
}

# ... duplicate all app variables with app2_ prefix
```

### Step 2: Add app2 modules to `main.tf`

```hcl
module "app2_network" {
  source = "../modules/network"
  count = var.app2_enabled ? 1 : 0
  project = var.app2_name
  # ... vars
}

module "app2_web_server" {
  source = "../modules/ec2_compute"
  count = var.app2_enabled ? 1 : 0
  security_group_id = module.app2_network[0].web_sg_id
  # ... vars
}

# ... continue pattern
```

### Step 3: Add app2 configuration to `free-tier.auto.tfvars`

```hcl
app2_enabled = true
app2_name = "wordpress"
app2_web_instance_type = "t3.small"
app2_domain_name = "wordpress.surfingclouds.io"
# ... etc
```

### Step 4: Deploy both

```bash
AWS_PROFILE=opentofu ~/.local/bin/tofu apply
```

**Both apps run independently with zero code duplication in modules.**

## Module Interface (Generic)

All modules use standard, CMS-agnostic terminology:

### `network`
- Input: `project`, `environment`, `vpc_cidr`, `availability_zones`, `subnet_cidrs`, `tags`
- Output: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `web_sg_id`, `database_sg_id`

### `web_server`
- Input: `project`, `name`, `instance_type`, `subnet_id`, `security_group_id`, `eip_allocation`
- Output: `instance_id`, `private_ip`, `public_ip`

### `database`
- Input: `project`, `name`, `engine`, `instance_class`, `db_name`, `username`, `password`, `subnet_ids`, `security_group_id`
- Output: `endpoint`, `address`, `port`, `db_name`

### `storage`
- Input: `project`, `bucket_name`, `versioning_enabled`, `server_side_encryption`, `lifecycle_rules`
- Output: `bucket_id`, `bucket_arn`, `bucket_domain_name`

**Pattern:** All modules accept `project` (app identifier) so outputs are namespaced per app.

## File Structure

```
free-tier/
├── variables.tf             # app_enabled, app_name, domain_name, db_*, etc.
├── main.tf                  # network, web_server, database, storage, dns
├── outputs.tf               # app_network, app_web_server, app_database, app_storage, app_dns
├── free-tier.auto.tfvars    # app_enabled=false, app_name="app"
└── ...

modules/
├── network/                 # VPC + SGs (generic)
├── web_server/              # EC2 (not in this version, uses ec2_compute)
├── database/                # RDS (not in this version, uses rds_database)
└── ...
```

## Deployment Examples

### Example 1: Deploy Ghost on surfingclouds.io

```hcl
# free-tier.auto.tfvars
app_enabled = true
app_name = "ghost"
domain_name = "surfingclouds.io"
db_name = "ghost"
```

### Example 2: Deploy WordPress on wordpress.surfingclouds.io

```hcl
# Add app2 variables + modules (see above)
app2_enabled = true
app2_name = "wordpress"
app2_domain_name = "wordpress.surfingclouds.io"
app2_db_name = "wordpress"
```

### Example 3: Deploy Custom App

```hcl
app_enabled = true
app_name = "myapp"
domain_name = "myapp.surfingclouds.io"
db_name = "myappdb"
```

**All three use identical infrastructure code. Just change variable values.**

## Best Practices

1. **Never commit secrets** — Use environment variables for `db_password`
   ```bash
   export TF_VAR_db_password="secure-pwd"
   tofu apply
   ```

2. **Use descriptive app_name** — It's used for tagging and naming all resources
   ```hcl
   app_name = "ghost"      # Good: clear
   app_name = "app"        # Okay: generic
   app_name = "x"          # Bad: unclear
   ```

3. **Keep separate variable prefixes for multi-app** — Use `app_*`, `app2_*`, `app3_*`
   - Makes scaling obvious
   - Easy to enable/disable individual apps
   - Clear dependency chains

4. **Document app-specific overrides** — If WordPress needs different settings, comment them in tfvars
   ```hcl
   # WordPress needs larger storage + better instance
   app2_db_allocated_storage = 50
   app2_web_instance_type = "t3.small"
   ```

---

**Design Philosophy:** Generic infrastructure, specific configuration. Modules never know or care about the app they're running.
