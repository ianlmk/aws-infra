# AWS Infrastructure Architecture

**Date Updated:** 2026-02-16  
**Status:** ✅ Network-first architecture complete

## Module Dependency Graph

```
┌─────────────────────────────────────┐
│         IAM (independent)           │
│      Route53 (independent)          │
└─────────────────────────────────────┘

                 ↓

         ┌───────────────┐
         │   Network     │ ⭐ PREREQUISITE
         │ (VPC + SGs)   │
         └───────────────┘
                 ↓
    ┌────────────┴─────────────┬──────────────┐
    ↓            ↓             ↓              ↓
┌────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐
│  Web   │  │ Database│  │ Storage  │  │  DNS    │
│ Server │  │  (RDS)  │  │ (S3)     │  │Records  │
│ (EC2)  │  │         │  │          │  │         │
└────────┘  └─────────┘  └──────────┘  └─────────┘
    ↑            ↑
    └────────────┴─ DNS references web server IP
```

## Module Responsibilities

### Core (Foundational)

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `network` | Composes VPC + security groups | vpc_network, security_groups |
| `vpc_network` | VPC, subnets, IGW, NAT (HA) | None |
| `security_groups` | Web/App/Database SG tiers | vpc_network |

### Compute & Storage

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `ec2_compute` | EC2 instances + EIP | network (for subnet, SG) |
| `rds_database` | RDS instances (MySQL/Postgres) | network (for subnets, SG) |
| `s3` | S3 buckets + encryption | None (independent) |

### Platform Services

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `route53` | Hosted zones + records | None (independent) |
| `iam` | IAM users, policies, keys | None (independent) |

## Composition Pattern: Application Stack (CMS/App Agnostic)

```hcl
# Step 1: Create Network (VPC + SGs)
module "network" {
  source = "../modules/network"
  project = var.app_name          # "ghost", "wordpress", "myapp", etc.
}

# Step 2: Create Web Server (uses network)
module "web_server" {
  source = "../modules/ec2_compute"
  subnet_id = module.network[0].public_subnet_ids[0]
  security_group_id = module.network[0].web_sg_id
}

# Step 3: Create Database (uses network)
module "database" {
  source = "../modules/rds_database"
  subnet_ids = module.network[0].private_subnet_ids
  security_group_id = module.network[0].database_sg_id
}

# Step 4: Create Storage
module "storage" {
  source = "../modules/s3"
  bucket_name = "backups"
}

# Step 5: Create DNS
resource "aws_route53_record" "web" {
  records = [module.web_server[0].public_ip]
}
```

**Generic variable prefix `app_*` means the same code deploys any CMS or app.**

## Design Principles

### 1. Network First

- **VPC is foundational** — all compute/database lives inside it
- **Security groups are prerequisites** — must exist before resources can attach
- **Network module bundles them** — single entry point for infrastructure foundation

### 2. No Circular Dependencies

- Network doesn't depend on compute/storage
- Compute/storage depend on network (linear)
- DNS depends on compute (linear)
- IAM and Route53 are independent

### 3. Reusability Without Copy-Paste

When adding `app2`:
1. Copy the ghost module blocks in `free-tier/main.tf`
2. Change `ghost` → `app2` in all variable names
3. No module code changes needed
4. Same network module, different values

### 4. Scalability

- **N apps** = N × (network + ec2 + rds + s3 + dns blocks)
- **Module count** = static (9 modules, always)
- **Code duplication** = none (composition handles variation)

## Network Architecture Details

### VPC Setup
- **CIDR:** 10.0.0.0/16
- **Public subnets:** 10.0.1.0/24, 10.0.2.0/24 (AZs a, b)
- **Private subnets:** 10.0.11.0/24, 10.0.12.0/24 (AZs a, b)
- **IGW:** 1 (attached to VPC)
- **NAT Gateways:** 2 (one per AZ, for HA)

### Security Groups

**Web Tier** (`web_sg`)
- Ingress: 80, 443, 22 (HTTP/HTTPS/SSH from anywhere)
- Egress: All outbound

**App Tier** (`app_sg`)
- Ingress: 3000 (from web_sg)
- Egress: All outbound

**Database Tier** (`database_sg`)
- Ingress: 3306 (MySQL from app_sg)
- Egress: All outbound

## File Structure

```
free-tier/
├── main.tf              # Orchestrates all modules
├── outputs.tf           # Exposes infrastructure state
├── variables.tf         # Ghost configuration variables
├── locals.tf            # Common tags, policies, etc.
├── backend.tf           # S3 state backend
├── bootstrap.tf         # S3 + DynamoDB bootstrap
├── cost-explorer.tf     # Cost tracking IAM policies
└── free-tier.auto.tfvars # Environment values

modules/
├── network/             # Composes VPC + SGs
├── vpc_network/         # Raw VPC primitives
├── security_groups/     # SG definitions
├── ec2_compute/         # EC2 primitives
├── rds_database/        # RDS primitives
├── s3/                  # S3 primitives
├── iam/                 # IAM primitives
└── route53/             # Route53 primitives
```

## Adding a New App

All apps use the same generic modules. To deploy a second app:

1. **Add app2 variables to `variables.tf`** (duplicate app_* with app2_ prefix):
   ```hcl
   variable "app2_enabled" { ... }
   variable "app2_name" { ... }
   variable "app2_web_instance_type" { ... }
   # etc. (same structure as app_*)
   ```

2. **Add app2 modules to `free-tier/main.tf`:**
   ```hcl
   module "app2_network" {
     source = "../modules/network"
     project = var.app2_name
   }
   
   module "app2_web_server" {
     source = "../modules/ec2_compute"
     security_group_id = module.app2_network[0].web_sg_id
   }
   # etc. (same pattern, app2_ prefix)
   ```

3. **Add app2 values to `free-tier.auto.tfvars`:**
   ```hcl
   app2_enabled = true
   app2_name = "wordpress"
   app2_domain_name = "wordpress.surfingclouds.io"
   # etc.
   ```

4. **Plan & apply:**
   ```bash
   tofu plan
   tofu apply
   ```

**No module code changes. Same generic infrastructure, different configuration.**

---

**Architecture approved by:** Network-first pattern, SRE-proven.  
**Last tested:** 2026-02-16 (HCL validation ✅)
