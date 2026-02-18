# WordPress Infrastructure Module

Terraform module for WordPress-specific AWS resources. Works in tandem with the `free-tier` base infrastructure.

## Architecture

```
free-tier/ (Base Infrastructure - One-time)
├── VPC, Subnets, Security Groups
├── EC2 t3.micro (shared web server)
├── Route53 zone
└── Outputs: VPC ID, EC2 instance ID, SG IDs

wordpress-infra/ (Application Infrastructure - Per-app)
├── RDS MySQL (database)
├── S3 bucket (uploads)
├── IAM role (EC2 permissions)
├── Ansible trigger (auto-deploy)
└── Reads base infrastructure outputs
```

## Deployment Pattern

### One-Time Setup

```bash
# 1. Pre-create RDS password in Vault
vault kv put secret/aws/wordpress/rds password=generate-secure-password-here

# 2. Deploy base infrastructure
cd aws-infra/free-tier
tofu apply
# Outputs: VPC ID, EC2 instance ID, security groups
```

### Deploy WordPress Application

```bash
# 3. Deploy WordPress-specific resources
cd ../wordpress-infra

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your domain, etc.

# Deploy
tofu init  # Initializes remote backend (same S3 bucket)
tofu apply  # Creates RDS, S3, IAM, triggers Ansible
```

### Cleanup (WordPress Only)

```bash
# Destroy WordPress resources ONLY
cd wordpress-infra
tofu destroy  # Removes RDS, S3, IAM

# Base infrastructure (free-tier) remains intact
# Can still deploy Ghost or other apps to the same EC2
```

## Resources Created

### RDS MySQL Database

- **Instance:** `db.t3.micro` (free tier eligible)
- **Storage:** 20 GB gp3 (free tier eligible)
- **Version:** MySQL 8.0.35 (configurable)
- **Backups:** 7-day retention, automated
- **Encryption:** Storage encrypted by default
- **Multi-AZ:** Disabled (free tier) — Enable for production
- **Monitoring:** Enhanced monitoring enabled

**Cost:** ~$0-10/month (free tier) to ~$15-30/month with storage

### S3 Bucket (WordPress Uploads)

- **Bucket:** `app1-wordpress-uploads-{ACCOUNT_ID}`
- **Access:** Private, only EC2 can read/write
- **Versioning:** Enabled (7-day cleanup of old versions)
- **Encryption:** AES256 by default
- **Lifecycle:** Auto-cleanup of incomplete uploads

**Cost:** ~$0.02-0.10/month (depending on upload volume)

### IAM Roles

- **WordPress EC2 Role:** Allows EC2 to access S3, CloudWatch Logs, optionally SSM
- **RDS Monitoring Role:** Enhanced monitoring
- **Instance Profile:** Attached to EC2 for S3 access

**Cost:** Free

### Ansible Deployment

- Automatically deploys WordPress via Ansible playbook
- Passes infrastructure outputs to Ansible (RDS endpoint, S3 bucket, etc.)
- Optional: Can disable and deploy manually

## Prerequisites

1. **Base infrastructure deployed** (free-tier/)
   ```bash
   cd free-tier
   tofu apply
   # Note the outputs: VPC ID, EC2 instance ID, security groups
   ```

2. **Vault password created**
   ```bash
   vault kv put secret/aws/wordpress/rds password=YOUR_SECURE_PASSWORD_HERE
   ```

3. **Terraform configured**
   ```bash
   terraform init
   ```

## Configuration

### Required Variables

```hcl
wordpress_url = "https://yourdomain.com"  # Full WordPress URL
```

### Optional but Recommended

```hcl
wordpress_admin_email = "admin@yourdomain.com"
rds_allocated_storage = 20  # GB
backup_retention_days = 7
skip_final_snapshot = true  # false for production
```

### Full Configuration

See `terraform.tfvars.example` for all available options.

## Deployment Steps

### 1. Initialize Terraform

```bash
cd wordpress-infra
terraform init
```

This configures the remote backend (same S3 bucket as free-tier, different state key).

### 2. Create/Update terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
vi terraform.tfvars
```

**Key settings:**
```hcl
wordpress_url = "https://yourdomain.com"
wordpress_admin_email = "admin@yourdomain.com"
deploy_wordpress = true  # Auto-deploy via Ansible
```

### 3. Plan and Review

```bash
terraform plan
```

Review the resources that will be created.

### 4. Apply

```bash
terraform apply
```

This will:
- Create RDS MySQL database
- Create S3 bucket
- Create IAM role and attach to EC2
- Create Ansible inventory entry
- Trigger Ansible playbook (if `deploy_wordpress = true`)

**Expected time:** 5-10 minutes for RDS to be ready

### 5. Verify Deployment

```bash
# SSH to EC2
ssh -i ~/.ssh/app1-web-key ansible@$(terraform output -raw ec2_public_ip)

# Check WordPress
sudo systemctl status apache2
curl http://127.0.0.1

# Check database
mysql -h $(terraform output -raw rds_address) -u wordpress -p
```

### 6. Complete WordPress Setup

```
Visit: https://yourdomain.com/wp-admin/
Follow the WordPress setup wizard
```

## Outputs

After `terraform apply`, you'll get:

```
rds_endpoint        = "app1-wordpress-mysql.xxxxx.us-east-2.rds.amazonaws.com:3306"
rds_address         = "app1-wordpress-mysql.xxxxx.us-east-2.rds.amazonaws.com"
s3_bucket_name      = "app1-wordpress-uploads-143551597089"
wordpress_url       = "https://yourdomain.com"
wordpress_admin_url = "https://yourdomain.com/wp-admin/"
ec2_public_ip       = "3.129.202.42"
setup_instructions  = "..."
```

## State Management

- **Local state:** Not used. All state in S3 bucket `tfstate-0001x`
- **State key:** `wordpress-infra/terraform.tfstate`
- **Locking:** DynamoDB table `terraform-locks` (automatic)
- **Encryption:** S3 bucket encrypted, versioning enabled

## Backups

### Automated RDS Backups

- **Retention:** 7 days (configurable)
- **Window:** 02:00-03:00 UTC (configurable)
- **Automatic:** Enabled by default
- **Final snapshot:** Skipped on destroy (set `skip_final_snapshot = false` in production)

### Manual Backup

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier app1-wordpress-mysql \
  --db-snapshot-identifier app1-wordpress-backup-$(date +%s)

# List snapshots
aws rds describe-db-snapshots --query "DBSnapshots[*].[DBSnapshotIdentifier,CreateTime]"
```

### S3 Backups

- S3 versioning keeps 7 days of old file versions
- Incomplete multipart uploads auto-cleaned after 7 days

## Disaster Recovery

### Restore from RDS Snapshot

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier app1-wordpress-restored \
  --db-snapshot-identifier app1-wordpress-backup-xxxxx

# Then import into WordPress via WP-CLI
wp db import dump.sql
```

### Restore from S3

S3 versioning allows recovery of deleted files:

```bash
aws s3api list-object-versions \
  --bucket app1-wordpress-uploads-143551597089 \
  --prefix wp-content/uploads/
```

## Troubleshooting

### RDS Not Ready

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier app1-wordpress-mysql \
  --query "DBInstances[0].[DBInstanceStatus,DBInstanceIdentifier]"
```

Status flow: `creating` → `backing-up` → `available` (10-15 minutes)

### Ansible Deployment Failed

```bash
# Check Terraform logs
terraform show

# SSH to EC2 and check Ansible
ssh -i ~/.ssh/app1-web-key ansible@<IP>
sudo journalctl -u apache2 -f
sudo tail -f /var/www/wordpress/wp-content/debug.log
```

### Database Connection Error

```bash
# Test connection
mysql -h <RDS_ENDPOINT> -u wordpress -p <DATABASE_NAME>

# Check security group
aws ec2 describe-security-groups --group-ids <SG_ID> \
  --query "SecurityGroups[0].IpPermissions"
```

### S3 Permissions Error

```bash
# Check IAM policy
aws iam get-role-policy --role-name app1-wordpress-ec2-role \
  --policy-name app1-wordpress-s3-uploads-policy

# Verify EC2 has role attached
aws ec2 describe-instances --instance-ids <INSTANCE_ID> \
  --query "Reservations[0].Instances[0].IamInstanceProfile"
```

## Scaling Beyond Free Tier

### Upgrade RDS Instance

```hcl
# In terraform.tfvars
rds_instance_class = "db.t3.small"  # $0.06/hour
rds_allocated_storage = 100         # 100 GB
```

Then `terraform apply`.

### Enable Multi-AZ (High Availability)

```hcl
# In variables.tf, add:
variable "multi_az" { default = false }

# In rds.tf, update:
multi_az = var.multi_az

# Then:
terraform apply
```

Cost impact: ~2x RDS cost for Multi-AZ.

## Cost Breakdown (Free Tier)

| Resource | Free Tier | After Free Tier |
|----------|-----------|-----------------|
| RDS t3.micro | $0 (750h/mo) | $10-15/mo |
| RDS storage | $0 (20 GB free) | $0.10/GB/mo |
| S3 bucket | $0.02 (minimal) | $0.023/GB/mo |
| EC2 (shared) | $0 | — |
| **Total** | **~$0.02/mo** | **~$15-20/mo** |

## Cleanup

### Destroy WordPress Infrastructure

```bash
# Removes: RDS, S3, IAM roles
terraform destroy

# Base infrastructure (free-tier) unaffected
```

### Full Cleanup

```bash
# Destroy WordPress
cd wordpress-infra
terraform destroy

# Then destroy base (if needed)
cd ../free-tier
terraform destroy
```

## Next Applications

Deploy more applications to the same EC2:

```bash
# Ghost on same EC2
cd ../ghost-infra
terraform apply

# Result: EC2 runs both WordPress and Ghost
# Nginx/Apache can reverse-proxy to both
```

## References

- [Terraform AWS RDS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [Terraform AWS S3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [WordPress on AWS](https://aws.amazon.com/blogs/startups/how-to-deploy-wordpress-on-aws/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
