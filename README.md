# AWS Infrastructure

Centralized infrastructure as code using **OpenTofu** (open-source successor to Terraform).

- **Why OpenTofu?** Open source (Apache 2.0), community-maintained, 100% compatible with Terraform HCL
- **Cost:** Free
- **State:** S3 + DynamoDB (encrypted, versioned, locked)

## Structure

```
accounts/
├── ghost-free-tier/        # Free tier Ghost blog account
│   ├── README.md
│   └── terraform/
│       ├── backend.tf      # S3 + DynamoDB backend config
│       ├── bootstrap.tf    # State management resources
│       └── variables.tf
```

## Getting Started

1. **Install OpenTofu:**
   ```bash
   # https://opentofu.org/docs/intro/install/
   brew install opentofu  # macOS
   # or download from https://github.com/opentofu/opentofu/releases
   ```

2. **Select an account:**
   ```bash
   cd accounts/<account-name>/terraform
   ```

3. **Initialize OpenTofu:**
   ```bash
   tofu init
   ```

4. **Plan changes:**
   ```bash
   tofu plan
   ```

5. **Apply:**
   ```bash
   tofu apply
   ```

## AWS Credentials

Each account has a dedicated IAM profile configured locally in `~/.aws/credentials`. See account-specific README for profile names.

## State Management

All OpenTofu state is stored in S3 with:
- Encryption enabled (AES256)
- Versioning enabled
- DynamoDB locking for concurrency
- Public access blocked

State files are never committed to this repository (see `.gitignore`).

## Adding New Accounts

1. Create `accounts/<account-name>/terraform/` directory
2. Create `backend.tf`, `variables.tf`, and resource files
3. Create `accounts/<account-name>/README.md` with account details
4. Document the account setup and any manual bootstrap steps
5. Update S3 bucket and DynamoDB table names in `backend.tf` for the new account

Example `backend.tf`:
```hcl
backend "s3" {
  bucket         = "tfstate-<project>-backend"
  key            = "<project>/terraform.tfstate"
  region         = "us-east-2"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

**Note:** Bucket names should not include account IDs or other identifying information. Use descriptive, anonymous names only.

## Cost Tracking

Monitor free tier usage and set up CloudWatch alarms to prevent unexpected charges.

---

**Never commit secrets, credentials, or PII to this repository.**
