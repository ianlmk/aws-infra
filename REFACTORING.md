# AWS Infrastructure Refactoring: Ghost to Resource-Type Modules

**Date:** 2026-02-16  
**Status:** ✅ Scaffolding Complete  

## Summary

Transitioned from **app-centric (ghost module)** to **resource-type composition** with **CMS/app-agnostic variable naming** for better scalability and maintainability.

Now the same infrastructure code works for Ghost, WordPress, or any custom app—just change variable prefixes and values.

## New Module Structure

**Dependency Hierarchy:**

```
VPC (vpc_network) ← prerequisite
    ↓
Security Groups (security_groups) ← depends on VPC
    ↓
Network (network) ← composes VPC + SGs
    ↓
EC2 / RDS / S3 / DNS ← all depend on Network
```

**Module Tree:**

```
modules/
├── network/               # ⭐ NEW: Composes VPC + Security Groups
│   ├── main.tf           # Calls vpc_network + security_groups
│   ├── variables.tf
│   └── outputs.tf        # Exposes both VPC and SG outputs
├── vpc_network/          # VPC, subnets, IGW, NAT, route tables
├── security_groups/      # Web, app, database SG tiers + rules
├── ec2_compute/          # EC2 instances + optional EIP
├── rds_database/         # RDS instances (MySQL/Postgres)
├── s3/                   # S3 buckets + versioning + encryption
├── iam/                  # ✅ Existing — unchanged
└── route53/              # ✅ Existing — unchanged
```

## Old Structure (Removed)

- ❌ `modules/ghost/` — Monolithic app-centric module
- All ghost functionality now composed in `free-tier/main.tf` from resource modules

## Key Benefits

| Aspect | Old | New |
|--------|-----|-----|
| **Add app 5** | Create ghost-duplicate module, diverge | Compose existing modules, no new code |
| **Policy change** | Touch N modules | Fix in 1 place |
| **Testing** | Test ghost specifically | Test module once, compose anywhere |
| **Cost controls** | Per-app enforcement | Resource-type enforcement |
| **Scalability** | O(N) modules | O(1) modules + composition |

## Composition Layer: `free-tier/main.tf`

**Network is the prerequisite. Everything depends on it.**

```hcl
# Network: VPC + Security Groups (prerequisite)
module "ghost_network" {
  source = "../modules/network"
  project = var.ghost_project_name
  ...
}

# All downstream resources consume from network
module "ghost_web" {
  source = "../modules/ec2_compute"
  subnet_id         = module.ghost_network[0].public_subnet_ids[0]
  security_group_id = module.ghost_network[0].web_sg_id
}

module "ghost_database" {
  source = "../modules/rds_database"
  subnet_ids        = module.ghost_network[0].private_subnet_ids
  security_group_id = module.ghost_network[0].database_sg_id
}

module "ghost_storage" {
  source = "../modules/s3"
  # S3 doesn't need network directly, but grouped logically
}

resource "aws_route53_record" "ghost_web" {
  # DNS references compute outputs
  records = [module.ghost_web[0].public_ip]
}
```

**Dependency Flow:**
1. Network created first (VPC + SGs)
2. Web server created (uses network outputs)
3. Database created (uses network outputs)
4. DNS records created (uses web server output)
5. Storage is independent (but grouped under ghost)

**Advantage:** Clear dependency graph. No circular dependencies. Easy to see what depends on what.

## Files Updated

- ✅ `modules/network/` — NEW (3 files) ⭐ Network composition layer
- ✅ `modules/vpc_network/` — NEW (3 files)
- ✅ `modules/security_groups/` — NEW (3 files)
- ✅ `modules/ec2_compute/` — NEW (3 files)
- ✅ `modules/rds_database/` — NEW (3 files)
- ✅ `modules/s3/` — NEW (3 files)
- ✅ `free-tier/main.tf` — UPDATED (now uses network module)
- ✅ `free-tier/outputs.tf` — UPDATED (Ghost outputs via network)
- ❌ `modules/ghost/` — DELETED

## Next Steps

1. **Validate HCL:**
   ```bash
   cd ~/workspace/seldon/aws-infra/free-tier
   AWS_PROFILE=opentofu ~/.local/bin/tofu validate
   ```

2. **Test plan (dry-run with ghost disabled first):**
   ```bash
   AWS_PROFILE=opentofu ~/.local/bin/tofu plan -var="ghost_enabled=false" -lock=false
   ```

3. **Enable Ghost & plan:**
   ```bash
   AWS_PROFILE=opentofu ~/.local/bin/tofu plan -var="ghost_enabled=true" -lock=false
   ```

4. **Apply when ready:**
   ```bash
   AWS_PROFILE=opentofu ~/.local/bin/tofu apply -var="ghost_enabled=true"
   ```

## Composition Rules (Reference)

When adding new apps, follow this strict pattern in `free-tier/main.tf`:

```hcl
# STEP 1: Network (VPC + Security Groups) — prerequisite for everything
module "app2_network" {
  source = "../modules/network"
  project = "app2"
  environment = var.environment
  # ... vpc_cidr, subnets, etc.
}

# STEP 2: Compute (depends on network)
module "app2_web" {
  source = "../modules/ec2_compute"
  subnet_id         = module.app2_network[0].public_subnet_ids[0]
  security_group_id = module.app2_network[0].web_sg_id
  # ... other vars
}

# STEP 3: Database (depends on network)
module "app2_db" {
  source = "../modules/rds_database"
  subnet_ids        = module.app2_network[0].private_subnet_ids
  security_group_id = module.app2_network[0].database_sg_id
  # ... other vars
}

# STEP 4: Storage (independent, but grouped logically)
module "app2_storage" {
  source = "../modules/s3"
  bucket_name = "backups"
  # ... other vars
}

# STEP 5: DNS (depends on compute outputs)
resource "aws_route53_record" "app2" {
  zone_id = module.route53.zones[<zone_key>].zone_id
  records = [module.app2_web[0].public_ip]
}
```

**Order Matters:**
1. Network first (no dependencies)
2. Compute/Database (depend on network)
3. Storage (independent)
4. DNS (depends on compute)

---

**Key Insight:** Network is the foundation. Everything builds on it. Linear, no circular deps, scales cleanly.
