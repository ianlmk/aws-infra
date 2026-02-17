# AWS Infrastructure Bootstrap

## Overview

This Terraform module sets up the **one-time bootstrap infrastructure** required to deploy the rest of the AWS infrastructure as code (IaC).

### What It Does

1. **Creates the `opentofu` IAM user** — A dedicated user for infrastructure automation
2. **Attaches 4 comprehensive policies:**
   - `ec2-keypair` — SSH key pair management
   - `infrastructure` — Full EC2, VPC, RDS, Route53, S3, KMS permissions
   - `state-backend` — S3 and DynamoDB access for Terraform state
   - `cost-explorer` — Cost tracking permissions
3. **Sets up the S3 state backend** — Centralized Terraform state storage with versioning
4. **Creates the DynamoDB lock table** — State locking to prevent concurrent modifications

### Why Bootstrap?

The chicken-and-egg problem:
- Terraform needs IAM permissions to create infrastructure
- But the opentofu user doesn't exist yet
- Solution: Bootstrap runs **as the admin user** (player1) to create the opentofu user and its policies

Once bootstrap is complete:
- The opentofu user has all necessary permissions
- Subsequent deployments can use the opentofu profile
- State is managed remotely in S3 with DynamoDB locking

---

## Prerequisites

- AWS credentials configured for **admin user** (`player1`) in `~/.aws/credentials` or `default` profile
- `terraform` or `tofu` installed (v1.6+)
- Ability to create IAM users, S3 buckets, and DynamoDB tables

---

## Quick Start

### Step 1: Run Bootstrap (as admin/player1)

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Terraform will output the access keys for the opentofu user.

### Step 2: Extract Access Keys

**Option A: View sensitive outputs**
```bash
terraform output opentofu_access_key_id
terraform output opentofu_secret_access_key
```

**Option B: Save to a temporary file** (more secure)
```bash
terraform output -json | jq '.opentofu_access_key_id.value, .opentofu_secret_access_key.value' > /tmp/keys.json
```

### Step 3: Add to `~/.aws/credentials`

Create a new profile for the opentofu user:

```ini
[opentofu]
aws_access_key_id = <ACCESS_KEY_ID from step 2>
aws_secret_access_key = <SECRET_ACCESS_KEY from step 2>
region = us-east-2
```

### Step 4: Verify Credentials

```bash
aws sts get-caller-identity --profile opentofu
```

Expected output:
```json
{
    "UserId": "AIDAXXX...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/opentofu"
}
```

### Step 5: Verify State Backend

```bash
# Test S3 access
aws s3 ls tfstate-ghost-p1 --profile opentofu

# Test DynamoDB access
aws dynamodb describe-table --table-name terraform-locks --region us-east-2 --profile opentofu
```

### Step 6: Deploy Infrastructure

Now that the opentofu user exists with proper permissions:

```bash
cd ../free-tier
terraform init    # Will detect and use S3 backend
terraform plan
terraform apply
```

---

## Configuration

### Variables

Edit `variables.tf` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `admin_profile` | `default` | AWS profile for admin user running bootstrap |
| `aws_region` | `us-east-2` | AWS region |
| `infra_user_name` | `opentofu` | IAM username for infrastructure automation |
| `state_bucket_name` | `tfstate-ghost-p1` | S3 bucket for Terraform state (must be globally unique) |
| `state_lock_table_name` | `terraform-locks` | DynamoDB table for state locking |

### Override Variables

```bash
# Use a different bucket name
terraform apply -var 'state_bucket_name=tfstate-my-project'

# Use a different admin profile
terraform apply -var 'admin_profile=production-admin'
```

---

## What Gets Created

### IAM User: `opentofu`

Permissions include:
- EC2 instance, volume, and security group management
- VPC, subnet, routing, and NAT gateway management
- RDS database management
- Route53 hosted zones and DNS records
- S3 bucket and object management
- KMS encryption key access
- Cost Explorer read access

See `main.tf` for full policy details.

### S3 Bucket: `tfstate-ghost-p1`

- Versioning enabled
- Server-side encryption (AES256)
- Public access blocked
- Stores Terraform state files

### DynamoDB Table: `terraform-locks`

- Pay-per-request billing
- Hash key: `LockID`
- Prevents concurrent state modifications

---

## Security Notes

⚠️ **Important:**

1. **Access Keys** are sensitive — store securely, never commit to Git
2. **State Files** may contain secrets — always use S3 with encryption
3. **Audit Permissions** — Review policies in `main.tf` and adjust if needed
4. **Key Rotation** — Regenerate access keys periodically
5. **Don't Commit** — `.gitignore` prevents accidental commits of state/keys

### Rotate Access Keys

To safely rotate opentofu credentials:

```bash
# Create new keys
aws iam create-access-key --user-name opentofu --profile default

# Update ~/.aws/credentials with new keys

# Delete old keys
aws iam delete-access-key --user-name opentofu --access-key-id OLD_KEY_ID --profile default
```

---

## Troubleshooting

### Error: "User with name opentofu cannot be found"

- Bootstrap hasn't run yet, OR
- Running as wrong profile (should be `default` or admin profile)

**Fix:** Run `terraform apply` in bootstrap directory as admin user.

### Error: "Access Denied" during opentofu deployment

- Bootstrap completed, but opentofu user lacks some permissions

**Check:**
```bash
aws iam list-attached-user-policies --user-name opentofu --profile opentofu
```

Should show 4 policies attached. If not, re-run bootstrap.

### Error: "S3 bucket name is already taken"

- S3 bucket names are globally unique
- Change `state_bucket_name` variable to something unique

**Fix:**
```bash
terraform apply -var 'state_bucket_name=tfstate-mycompany-ghost-p1'
```

### "Insufficient permissions for this action"

- opentofu user doesn't have permission for the action
- Check `main.tf` for the required action in the policy
- May need to add custom policy

---

## Cleanup (Destroy)

⚠️ **Warning:** This will delete the opentofu user, S3 state bucket, and DynamoDB lock table.

```bash
terraform destroy
```

You'll be prompted to confirm. After destruction:
- The opentofu user and keys are deleted
- The S3 bucket and all state files are deleted
- You'll need to re-run bootstrap to deploy again

---

## Next Steps

After bootstrap completes successfully:

1. ✅ opentofu user created with full permissions
2. ✅ S3 state backend ready
3. ✅ Access keys added to `~/.aws/credentials`

Then:
- Deploy Ghost infrastructure: `cd ../free-tier && terraform apply`
- Monitor costs: Use the `cheapass` tool with opentofu credentials
- Audit resources: Use the `state_check` tool to find billable resources

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│ Bootstrap (runs once as admin/player1)  │
├─────────────────────────────────────────┤
│                                         │
│  1. Create opentofu IAM user           │
│  2. Attach 4 policies                  │
│  3. Create S3 state bucket             │
│  4. Create DynamoDB lock table         │
│                                         │
└──────────────┬──────────────────────────┘
               │ Output: Access Keys
               ▼
┌─────────────────────────────────────────┐
│ Add to ~/.aws/credentials [opentofu]    │
├─────────────────────────────────────────┤
│  aws_access_key_id = ...               │
│  aws_secret_access_key = ...           │
│  region = us-east-2                    │
└──────────────┬──────────────────────────┘
               │ Use profile=opentofu
               ▼
┌─────────────────────────────────────────┐
│ Deploy Infrastructure (free-tier)       │
├─────────────────────────────────────────┤
│  terraform init                         │
│  terraform plan                         │
│  terraform apply                        │
│                                         │
│  State stored in S3 with DynamoDB lock │
└─────────────────────────────────────────┘
```

---

## References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [DynamoDB Locking for Terraform](https://www.terraform.io/docs/language/settings/backends/s3.html#dynamodb-table-permissions)
