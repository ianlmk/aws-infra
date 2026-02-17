# AWS Infrastructure Deployment Guide

## Overview

This guide walks through the complete deployment process from bootstrap to live infrastructure.

```
┌──────────────────────┐
│   Bootstrap Phase    │  Run ONCE as admin (player1)
│  (creates opentofu)  │  Creates IAM user, S3, DynamoDB
└──────────────┬───────┘
               │
               ▼
┌──────────────────────┐
│  Configure Profile   │  Add opentofu credentials to ~/.aws/credentials
│   in ~/.aws/config   │  One-time setup
└──────────────┬───────┘
               │
               ▼
┌──────────────────────┐
│  Deploy Ghost Infra  │  Run as opentofu user
│   (free-tier/)       │  Deploy EC2, RDS, DNS, etc.
└──────────────────────┘
```

---

## Phase 1: Bootstrap (ONE TIME ONLY)

### What It Does

Runs **as admin** (player1) to:
- Create the `opentofu` IAM user
- Attach comprehensive policies for infrastructure management
- Set up S3 state backend with versioning
- Create DynamoDB lock table for state management

### Step-by-Step

```bash
# 1. Navigate to bootstrap directory
cd aws-infra/bootstrap

# 2. Initialize Terraform
terraform init

# 3. Review what will be created
terraform plan

# 4. Apply (will run as your default AWS profile = player1/admin)
terraform apply

# Confirm: type 'yes'
```

### Get the Access Keys

```bash
# Display sensitive outputs (access keys)
terraform output opentofu_access_key_id
terraform output opentofu_secret_access_key

# Copy these values — you'll need them next
```

---

## Phase 2: Configure AWS Profile

### Add opentofu Credentials

Edit `~/.aws/credentials`:

```ini
[opentofu]
aws_access_key_id = <PASTE_ACCESS_KEY_ID>
aws_secret_access_key = <PASTE_SECRET_ACCESS_KEY>
region = us-east-2
```

### Verify It Works

```bash
aws sts get-caller-identity --profile opentofu

# Should output:
# {
#     "UserId": "AIDA...",
#     "Account": "870946031520",
#     "Arn": "arn:aws:iam::870946031520:user/opentofu"
# }
```

### Verify State Backend

```bash
# Test S3
aws s3 ls tfstate-ghost-p1 --profile opentofu

# Test DynamoDB
aws dynamodb describe-table \
  --table-name terraform-locks \
  --region us-east-2 \
  --profile opentofu
```

---

## Phase 3: Deploy Infrastructure

### Start Vault (if not running)

```bash
# Start Vault dev server with root token
vault server -dev -dev-root-token-id="seldon" &

# Set environment variables
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="seldon"

# Verify secrets exist
vault kv get secret/ghost/ssh
vault kv get secret/ghost/rds
```

### Deploy Ghost Infrastructure

```bash
# Navigate to free-tier directory
cd aws-infra/free-tier

# Initialize with S3 backend (will detect and ask about migration)
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="seldon"
export TF_VAR_vault_token="seldon"

terraform apply

# Confirm: type 'yes'
```

### Deployment Outputs

Once apply completes, you'll get:
- EC2 instance ID and public IP
- RDS endpoint and port
- Route53 DNS records
- Vault secrets paths

Example:
```
Outputs:

databases = {
  "ghost" = {
    "db_endpoint" = "ghost-rds.c9akciq32.us-east-2.rds.amazonaws.com:3306"
    "db_name" = "ghostdb"
    "engine" = "mysql"
  }
}
web_servers = {
  "ghost" = {
    "instance_id" = "i-0abc123def456"
    "private_ip" = "10.0.1.5"
    "public_ip" = "18.222.123.45"
  }
}
route53_zones = {
  "primary" = {
    "domain_name" = "surfingclouds.io"
    "zone_id" = "Z123ABC456DEF"
  }
}
```

---

## Verification Checklist

### After Deployment

```bash
# 1. Check EC2 instance is running
aws ec2 describe-instances \
  --instance-ids i-0abc123def456 \
  --region us-east-2 \
  --profile opentofu

# 2. Check RDS is available
aws rds describe-db-instances \
  --db-instance-identifier ghost-mysql \
  --region us-east-2 \
  --profile opentofu

# 3. Test DNS
nslookup surfingclouds.io

# 4. SSH into instance (using Vault key)
PRIVATE_KEY=$(vault kv get -field=private_key secret/ghost/ssh)
echo "$PRIVATE_KEY" > /tmp/ghost-key.pem
chmod 600 /tmp/ghost-key.pem
ssh -i /tmp/ghost-key.pem ubuntu@18.222.123.45

# 5. From EC2, test database connectivity
mysql -h ghost-rds.c9akciq32.us-east-2.rds.amazonaws.com \
  -u admin \
  -p <PASSWORD_FROM_VAULT> \
  -D ghostdb
```

---

## State Management

### Where State Is Stored

**Bootstrap state:**
- Location: `bootstrap/terraform.tfstate` (local, not committed)
- Purpose: Tracks IAM user, S3 bucket, DynamoDB table

**Infrastructure state:**
- Location: `s3://tfstate-ghost-p1/ghost/terraform.tfstate`
- Locking: DynamoDB table `terraform-locks`
- Encryption: AES256 (default)

### Viewing State

```bash
# Show all resources
terraform state list

# Show specific resource
terraform state show aws_instance.web

# Pull state from S3 (usually auto)
terraform state pull
```

---

## Cost Monitoring

### Check Current Spend

```bash
# Install cheapass if not already
cd ~/workspace/seldon/cheapass
make install

# Check resources
state_check --profile opentofu --region us-east-2

# Check costs
cheapass --profile opentofu cost
```

### Expected Monthly Cost (Free Tier)

- EC2 t3.micro: FREE (750h/month)
- RDS db.t3.micro: FREE (750h/month)
- Route53: $0.50/month
- **Total: ~$0.50/month**

If costs are higher, check:
- Is NAT Gateway enabled? ($32/month)
- Is EIP unattached? ($3.50/month)
- Are resources outside free tier?

---

## Destroying Infrastructure

### Destroy Everything (WARNING)

```bash
# Destroy free-tier infrastructure
cd aws-infra/free-tier
terraform destroy

# Destroy bootstrap (removes opentofu user, S3, DynamoDB)
cd ../bootstrap
terraform destroy
```

### Selective Destruction

```bash
# Destroy only EC2
terraform destroy -target=module.web_server

# Destroy only RDS
terraform destroy -target=module.database
```

---

## Troubleshooting

### "Terraform cannot assume the specified role"

**Cause:** opentofu user doesn't have permissions

**Fix:**
```bash
# Verify opentofu user was created
aws iam list-users --profile default | grep opentofu

# Check attached policies
aws iam list-attached-user-policies --user-name opentofu --profile default
```

### "S3 bucket already exists"

**Cause:** Bucket name is globally unique; someone else owns it

**Fix:** Change `state_bucket_name` in bootstrap variables:
```bash
terraform apply -var 'state_bucket_name=tfstate-YOURNAME-ghost-p1'
```

### "DynamoDB lock held by another process"

**Cause:** Another Terraform/opentofu process is running

**Fix:** Wait for it to complete, or:
```bash
# Force unlock (use carefully)
terraform force-unlock <LOCK_ID>
```

### "Vault secrets not found"

**Cause:** Vault server not running or secrets not created

**Fix:**
```bash
# Start Vault
vault server -dev -dev-root-token-id="seldon" &

# Set environment
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="seldon"

# Create secrets
vault kv put secret/ghost/ssh private_key=@~/.ssh/id_rsa public_key=@~/.ssh/id_rsa.pub
# ... repeat for rds, aws
```

---

## Next Steps

After deployment:

1. **Connect to EC2** — Install Ghost, configure application
2. **Monitor costs** — Use `cheapass` and `state_check` tools
3. **Backup database** — Set up RDS automated backups
4. **Secure access** — Use Vault to rotate credentials
5. **Document** — Update deployment runbooks

---

## Directory Structure

```
aws-infra/
├── bootstrap/              # One-time setup (creates opentofu user)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── README.md
│   └── terraform.tfvars.example
│
├── free-tier/              # Ghost infrastructure deployment
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vault.tf
│   ├── user-data.sh
│   ├── free-tier.auto.tfvars
│   └── backend.tf
│
├── modules/                # Reusable modules
│   ├── network/
│   ├── ec2_compute/
│   ├── rds_database/
│   ├── route53/
│   ├── s3/
│   └── iam/
│
├── DEPLOYMENT_GUIDE.md     # This file
├── README.md
└── .gitignore
```

---

## References

- [Bootstrap README](./bootstrap/README.md) — Detailed bootstrap guide
- [free-tier README](./free-tier/INFRASTRUCTURE.md) — Infrastructure details
- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS Free Tier](https://aws.amazon.com/free/free-tier-faqs/)
