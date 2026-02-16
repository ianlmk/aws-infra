# Free-Tier Infrastructure

## Overview

This directory manages infrastructure for the **free-tier AWS account** using **OpenTofu**.

- **AWS Account ID:** `<ACCOUNT_ID>` (see `~/.aws/config` or `aws sts get-caller-identity`)
- **Region:** `us-east-2`
- **State Backend:** S3 + DynamoDB (remote)
- **State Bucket:** `tfstate-<project>`
- **Lock Table:** `terraform-locks`

---

## Current Infrastructure

### Bootstrap (State Management)

**Purpose:** Remote state backend to persist infrastructure state across machines.

| Resource | Type | Status | Purpose |
|----------|------|--------|---------|
| `tfstate-<project>` | S3 Bucket | ✅ Active | Encrypted state storage (versioned) |
| `terraform-locks` | DynamoDB Table | ✅ Active | Concurrency locking |

**Configuration:**
- Encryption: AES256 (at rest)
- Versioning: Enabled
- Public Access: Blocked
- Billing Mode: On-demand (pay-per-request)

---

## IAM Users & Permissions

### `opentofu` User

**Purpose:** Service account for infrastructure automation (CI/CD, local CLI).

| Entity | Type | Details |
|--------|------|---------|
| `opentofu` | IAM User | Infrastructure automation |
| `opentofu-state-backend` | IAM Policy | S3 + DynamoDB access only |
| Access Keys | 1 active | Rotated regularly |

**Permissions:**
- S3: `ListBucket`, `GetBucketVersioning`, `GetObject`, `PutObject`, `DeleteObject` (on `tfstate-*` buckets)
- DynamoDB: `DescribeTable`, `GetItem`, `PutItem`, `DeleteItem` (on `terraform-locks` table)

**Profile:** `AWS_PROFILE=opentofu` or credentials in `~/.aws/credentials`

---

## Projects

### Ghost (Planned)

**Status:** 🔄 In Design

**Purpose:** Self-hosted blogging platform for personal/family content.

**Planned Components:**
- [ ] RDS (MySQL)
- [ ] EC2 (or Lightsail for simplicity)
- [ ] S3 (media storage)
- [ ] CloudFront (CDN) — optional
- [ ] Route53 (DNS) — optional

**Scope:** Free tier eligible (micro instances, small DB).

---

## Environment Variables

**File:** `free-tier.auto.tfvars`

| Variable | Value | Purpose |
|----------|-------|---------|
| `environment` | `free-tier` | Environment name for tagging |
| `project_name` | `ghost` | Project identifier |
| `common_tags` | See tfvars | Applied to all resources |

---

## Modules

### `../modules/iam`

**Purpose:** Reusable IAM management (users, policies, access keys).

**Inputs:**
- `iam_users` — Map of users to create
- `user_policies` — Map of policies to attach
- `create_access_keys` — List of users needing keys
- `environment` — For tagging
- `tags` — Common tags

**Outputs:**
- `users` — Created user details (ARN, ID, name)
- `access_keys` — Key IDs and creation dates
- `access_keys_secret` — Secret access keys (sensitive)
- `policies` — Created policies (ARN, name)

---

## File Structure

```
free-tier/
├── INFRASTRUCTURE.md          # This file
├── backend.tf                 # S3 state backend config
├── bootstrap.tf               # Bootstrap resources (S3, DynamoDB)
├── locals.tf                  # Computed values & policy definitions
├── variables.tf               # Variable declarations
├── main.tf                    # Root composition (calls modules)
├── outputs.tf                 # Exposed outputs
├── free-tier.auto.tfvars      # Environment configuration
├── .terraform/                # Provider cache (gitignored)
└── .terraform.lock.hcl        # Lock file (committed)
```

---

## Usage

### Initialize

```bash
cd ~/workspace/seldon/aws-infra/free-tier
AWS_PROFILE=opentofu ~/.local/bin/tofu init
```

### Plan

```bash
AWS_PROFILE=opentofu ~/.local/bin/tofu plan
```

### Apply

```bash
AWS_PROFILE=opentofu ~/.local/bin/tofu apply
```

### Alias (optional)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias ofu='AWS_PROFILE=opentofu ~/.local/bin/tofu'
```

Then: `ofu plan`, `ofu apply`, etc.

---

## Cost Estimation

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| S3 (state) | ~$0.02 | Minimal (versioning + lock table) |
| DynamoDB | $0 | On-demand, light usage |
| Ghost infrastructure | TBD | Depends on final design |

**Free Tier:** 12 months free for new AWS accounts (EC2 micro, RDS micro, etc.)

---

## Security

### Credentials
- Access keys stored in `~/.aws/credentials` (file perms: `600`)
- Never committed to git (`.gitignore` enforced)
- Rotated regularly and when compromised

### State Management
- State encrypted at rest (AES256)
- Versioning enabled (recovery if needed)
- DynamoDB locking prevents concurrent applies
- Sensitive outputs marked (not logged)

### IAM
- `opentofu` user: Minimal permissions (state backend only)
- Additional resources: Dedicated policies per-project
- MFA: Not configured for service account (consider for console access)

---

## Next Steps

### Immediate
- [ ] Define Ghost infrastructure (RDS, EC2, S3 config)
- [ ] Create `modules/ghost` for Ghost-specific resources
- [ ] Add Ghost-specific policies to `opentofu` user

### Soon
- [ ] CI/CD integration (GitHub Actions, GitLab CI)
- [ ] Backup strategy for databases
- [ ] Monitoring & alerts

### Future
- [ ] Multi-environment (prod, staging)
- [ ] Cross-region failover
- [ ] Cost tracking & budgets

---

## References

- **Terraform:** https://registry.terraform.io/
- **OpenTofu:** https://opentofu.org/
- **AWS:** https://aws.amazon.com/
- **Ghost:** https://ghost.org/

---

*Last Updated: See git history*
