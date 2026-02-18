# aws-infra

![Terraform](https://github.com/ianlmk/aws-infra/actions/workflows/terraform.yml/badge.svg)

Infrastructure-as-code for AWS deployments. Modular, free-tier eligible, production-ready.

**Status:** ✅ Production-ready with CI/CD and automated testing

---

## Architecture

```
free-tier/              (Network Scaffold - One-time)
├── Network foundation: VPC, subnets, security groups, Route53
└── Shared by all applications

wordpress-infra/        (Application - Independent)
├── EC2 instance (t3.micro, free tier)
├── RDS MySQL (db.t3.micro, free tier)
├── S3 bucket (uploads)
├── IAM roles (EC2 permissions)
└── Triggers Ansible deployment

ghost-infra/            (Application - Independent, Future)
├── EC2 instance (t3.micro, free tier)
├── RDS MySQL (db.t3.micro, free tier)
├── S3 bucket (uploads)
└── Same VPC, independent lifecycle

bootstrap/              (Deprecated - moved to account setup)
├── Created admin account IAM resources
└── Reference: GitHub Releases for historical code
```

---

## Quick Start

### Prerequisites

- OpenTofu >= 1.6 (or Terraform >= 1.6)
- AWS account with credentials
- S3 bucket for remote state (`tfstate-0001x`)
- DynamoDB table for locking (`terraform-locks`)
- Vault running locally (for secrets)

### Installation

```bash
# Install OpenTofu
brew install opentofu  # macOS
# Or download from https://opentofu.org

# Clone this repo
git clone https://github.com/ianlmk/aws-infra.git
cd aws-infra

# Export credentials
export AWS_PROFILE=opentofu
export AWS_REGION=us-east-2
export TF_VAR_vault_token=seldon  # Your Vault token
```

### Phase 1: Deploy Network Scaffold

```bash
cd free-tier

# Initialize
tofu init

# Plan (review changes)
tofu plan

# Apply (create VPC, subnets, security groups, Route53)
tofu apply

# Outputs: VPC ID, subnet IDs, security group IDs
```

### Phase 2: Deploy WordPress Application

```bash
cd ../wordpress-infra

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit: wordpress_url, database credentials

# Initialize
tofu init

# Plan
tofu plan

# Apply (creates EC2 + RDS + S3 + deploys app)
tofu apply

# Outputs: EC2 IP, RDS endpoint, S3 bucket name
```

---

## Two-Phase Deployment Pattern

### Why Separate?

**free-tier** (Shared Infrastructure):
- ✅ One-time deployment
- ✅ Shared by all applications
- ✅ Network foundation (VPC, subnets, SGs)
- ✅ DNS (Route53)

**app-infra** (Application-Specific):
- ✅ Independent deployment
- ✅ Own EC2, RDS, S3
- ✅ Can be destroyed without affecting other apps
- ✅ Self-contained state file

---

## Modules & Files

### free-tier/ - Network Scaffold

| File | Purpose |
|------|---------|
| `main.tf` | Network modules only (VPC, Route53) |
| `variables.tf` | Network-only variables |
| `outputs.tf` | VPC ID, subnet IDs, SG IDs, zone IDs |
| `free-tier.auto.tfvars` | Example configuration |
| `backend.tf` | Remote S3 state backend |
| `data.tf` | AWS account & region data sources |

**Resources:** 8-12 (VPC, subnets, SGs, Route53)

**Cost:** $0.50/month (Route53 only)

### wordpress-infra/ - WordPress Application

| File | Purpose |
|------|---------|
| `main.tf` | Provider config, data sources |
| `rds.tf` | RDS MySQL database |
| `s3.tf` | S3 bucket for uploads |
| `iam.tf` | IAM roles for EC2 |
| `ansible.tf` | EC2 instance + Ansible trigger |
| `variables.tf` | Application variables |
| `outputs.tf` | EC2 IP, RDS endpoint, S3 bucket |
| `terraform.tfvars.example` | Example configuration |
| `backend.tf` | Remote S3 state backend |

**Resources:** 15-20 (EC2, RDS, S3, IAM, SGs)

**Cost:** FREE (during free tier) / $15-20/month (after)

---

## Configuration

### Environment Variables

```bash
export AWS_PROFILE=opentofu      # AWS credentials
export AWS_REGION=us-east-2      # Target region
export TF_VAR_vault_token=seldon # Vault authentication
```

### terraform.tfvars (wordpress-infra)

```hcl
# Required
wordpress_url = "https://yourdomain.com"

# Optional (defaults provided)
wordpress_admin_email = "admin@yourdomain.com"
rds_allocated_storage = 20
backup_retention_days = 7
skip_final_snapshot = true
enable_deletion_protection = false
```

See `terraform.tfvars.example` for all options.

---

## State Management

### Remote State Backend

All modules use S3 + DynamoDB:

```hcl
backend "s3" {
  bucket         = "tfstate-0001x"
  key            = "free-tier/terraform.tfstate"  # Per module
  dynamodb_table = "terraform-locks"
  region         = "us-east-2"
}
```

**Why?**
- ✅ State survives session restarts
- ✅ DynamoDB locking prevents race conditions
- ✅ S3 versioning enables rollback
- ✅ Shared state across team

---

## CI/CD Pipeline

![Terraform](https://github.com/ianlmk/aws-infra/actions/workflows/terraform.yml/badge.svg)

**Workflow:** `.github/workflows/terraform.yml`

### On PR
- ✅ `tofu validate` (syntax check)
- ✅ `tofu plan` (show what would change)
- ✅ `tofu fmt -check` (format validation)
- ✅ Cost estimation
- ✅ PR comments with plan summary

**Duration:** 4-5 minutes per module

### On Merge to main
- ✅ Manual approval gate (production environment)
- ✅ `tofu apply` (deploy infrastructure)
- ✅ Sequential deployment (prevent race conditions)
- ✅ State locked during apply (DynamoDB)

**Duration:** 15-20 minutes (RDS dominates)

### Cost
- **Before:** Private repo, 2,000 min/month free
- **After:** Public repo, UNLIMITED free
- **Result:** $0/month forever

---

## Deployment Scenarios

### Deploy WordPress Only

```bash
cd wordpress-infra
tofu apply
# Creates: EC2, RDS, S3, IAM
# Deploys: WordPress via Ansible
```

### Destroy WordPress (Keep Network)

```bash
cd wordpress-infra
tofu destroy
# Removes: EC2, RDS, S3, IAM
# Preserves: VPC, subnets, Route53
```

### Deploy Ghost on Same Network

```bash
cd ../ghost-infra
tofu apply
# Creates: EC2, RDS, S3, IAM (Ghost-specific)
# Uses: Same VPC from free-tier
# Deploys: Ghost via Ansible
```

### Full Cleanup

```bash
# 1. Destroy all apps
cd wordpress-infra && tofu destroy
cd ../ghost-infra && tofu destroy

# 2. Destroy network scaffold
cd ../free-tier && tofu destroy
```

---

## Generic Naming Convention (OPSEC)

All resource names are generic (no project/CMS/account identifiers):

```hcl
# ✅ Good
name = "${app_name}-web"          # app1-web
bucket = "tfstate-0001x"          # Generic
database = "wordpress"            # App name

# ❌ Bad (Don't do this!)
name = "ghost-prod-web"           # Identifies project
bucket = "tfstate-ghost-account-123"  # Reveals details
```

**Why?** Committed code is world-readable. Generic naming prevents reconnaissance.

---

## Cost Breakdown

### During Free Tier (12 months)

| Service | Resource | Cost/Month |
|---------|----------|-----------|
| **Network** | Route53 zone | $0.50 |
| **Compute** | EC2 t3.micro | FREE (750h) |
| **Database** | RDS db.t3.micro | FREE (750h) |
| **Storage** | S3 bucket | ~$0.02 |
| **Total** | | **~$0.52** |

### After Free Tier Expires

| Service | Resource | Cost/Month |
|---------|----------|-----------|
| **Network** | Route53 zone | $0.50 |
| **Compute** | EC2 t3.micro | $7-10 |
| **Database** | RDS db.t3.micro | $10-15 |
| **Storage** | S3 bucket | ~$0.02 |
| **Total** | | **~$18-25** |

---

## Troubleshooting

### S3 Access Denied

```bash
# Ensure AWS_PROFILE has S3 permissions
aws s3 ls s3://tfstate-0001x --profile opentofu

# Verify backend config
cat free-tier/backend.tf
```

### DynamoDB Lock Stuck

```bash
# Force unlock if needed
tofu force-unlock -force <LOCK_ID>
```

### State Corrupted

```bash
# Emergency cleanup script (use with caution!)
./cleanup-nuclear.sh opentofu us-east-2
```

### Terraform Format Issues

```bash
# Fix formatting
tofu fmt -recursive
```

---

## Advanced Topics

### Multi-Environment Setup

```bash
# Dev environment
mkdir -p free-tier-dev
# Configure separately with dev-specific vars

# Staging
mkdir -p free-tier-staging

# Production (current setup)
free-tier/
```

### Cost Control

```hcl
# Don't enable these (costs money!)
enable_nat_gateways = false    # $32/month each
eip_allocation = false          # $3.50/month unattached
multi_az = false                # 2x RDS cost

# Keep free tier eligible
rds_instance_class = "db.t3.micro"
ec2_instance_type = "t3.micro"
```

### Monitoring & Alerts

```bash
# Use cheapass to track costs
cheapass --region us-east-2 --profile seldon

# Set AWS billing alerts (AWS Console)
# Budget > $20/month = investigate
```

---

## Repository Links

Related Projects:
- **ansible-core:** https://github.com/ianlmk/ansible-core (Configuration management)
- **cheapass:** https://github.com/ianlmk/cheapass (Cost tracking)
- **gcp-infra:** https://github.com/ianlmk/gcp-infra (GCP equivalent)

---

## Documentation

- `DEPLOYMENT_FLOW_TEST.md` — Complete deployment walkthrough
- `FREE_TIER_GUIDE.md` — Cost management and free tier details
- `DESTROY_PATTERNS.md` — Safe cleanup procedures
- `ARCHITECTURE.md` — Module dependency graphs
- `APP_AGNOSTIC.md` — How to deploy different CMSs

---

## Best Practices

1. **Always plan first**
   ```bash
   tofu plan -out=tfplan
   ```

2. **Review changes before applying**
   ```bash
   tofu show tfplan
   ```

3. **Use remote state** (don't commit terraform.tfstate)
   ```bash
   echo "*.tfstate*" >> .gitignore
   ```

4. **Enable deletion protection** for production
   ```hcl
   enable_deletion_protection = true
   ```

5. **Lock state during apply**
   ```bash
   tofu apply -lock=true -lock-timeout=10m
   ```

6. **Monitor costs regularly**
   ```bash
   cheapass --region us-east-2
   ```

---

## Performance

| Operation | Duration | Notes |
|-----------|----------|-------|
| tofu plan | 1-2 min | Quick validation |
| tofu apply (network) | 3-5 min | VPC creation fast |
| tofu apply (RDS) | 10-15 min | RDS creation slow |
| tofu destroy | 10-15 min | RDS deletion slow |

Total deployment: 15-20 minutes (mostly RDS creation time)

---

## License

_(Add your license here)_

---

## Contributing

Found a bug? Want to improve infrastructure patterns?

1. Fork the repo
2. Create feature branch (`git checkout -b feature/improve-thing`)
3. Commit changes (`git commit -am "Improve thing"`)
4. Push to branch (`git push origin feature/improve-thing`)
5. Open Pull Request

**CI/CD will automatically validate** your changes (tofu validate, plan, cost check).

---

## Support

- **GitHub Issues:** https://github.com/ianlmk/aws-infra/issues
- **Terraform Docs:** https://www.terraform.io/docs/
- **OpenTofu Docs:** https://opentofu.org/docs/
- **AWS Docs:** https://docs.aws.amazon.com/
