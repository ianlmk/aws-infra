# AWS Infrastructure

Centralized Terraform infrastructure for all AWS accounts.

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

1. **Select an account:**
   ```bash
   cd accounts/<account-name>/terraform
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan changes:**
   ```bash
   terraform plan
   ```

4. **Apply:**
   ```bash
   terraform apply
   ```

## AWS Credentials

Each account has a dedicated IAM profile configured locally in `~/.aws/credentials`. See account-specific README for profile names.

## State Management

All Terraform state is stored in S3 with:
- Encryption enabled
- Versioning enabled
- DynamoDB locking for concurrency

State files are never committed to this repository.

## Adding New Accounts

1. Create `accounts/<account-name>/terraform/` directory
2. Create `backend.tf`, `variables.tf`, and resource files
3. Create `accounts/<account-name>/README.md` with account details
4. Document the account setup and any manual bootstrap steps

## Cost Tracking

Monitor free tier usage and set up CloudWatch alarms to prevent unexpected charges.

---

**Never commit secrets, credentials, or PII to this repository.**
