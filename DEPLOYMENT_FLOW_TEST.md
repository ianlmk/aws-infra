# Deployment and Teardown Testing Guide

## Architecture

```
free-tier/           (Network scaffold - deployed ✅)
├── VPC + subnets
├── Security groups
└── Route53 zones

wordpress-infra/     (Application - ready for testing)
├── EC2 instance
├── RDS database
├── S3 bucket
└── IAM roles
```

## Phase 1: Deploy free-tier (COMPLETED ✅)

```bash
cd ~/workspace/seldon/aws-infra/free-tier
export AWS_PROFILE=opentofu
export TF_VAR_vault_token=seldon
export AWS_REGION=us-east-2

tofu init      # ✅ Done
tofu plan      # ✅ Verified
tofu apply     # ✅ Complete

# Outputs: VPC ID, subnet IDs, security group IDs
```

**Result:** Network infrastructure deployed. Ready for applications.

---

## Phase 2: Deploy wordpress-infra (READY)

### Prerequisites

1. **Vault secret created:**
```bash
VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=seldon vault kv put secret/aws/wordpress/rds password=YOUR_PASSWORD
```
✅ Done

2. **AWS credentials:**
```bash
export AWS_PROFILE=opentofu
export AWS_REGION=us-east-2
export TF_VAR_vault_token=seldon
```

3. **Configuration:**
```bash
cd ~/workspace/seldon/aws-infra/wordpress-infra
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
#   wordpress_url = "https://yourdomain.com"
#   deploy_wordpress = false (manual deployment)
```

### Deploy

```bash
tofu init
tofu plan
tofu apply -auto-approve
```

**Expected Resources Created:**
- 1 EC2 instance (t3.micro, free tier)
- 1 RDS MySQL database (db.t3.micro, free tier)
- 1 S3 bucket (WordPress uploads)
- 3 IAM roles (EC2, RDS monitoring)
- 2 Security groups (web, database)
- 1 Ansible inventory file

**Time:** ~5-10 minutes (mostly RDS creation time)

---

## Phase 3: Test Teardown

### Scenario 1: Destroy WordPress Only (APP-LEVEL)

```bash
cd ~/workspace/seldon/aws-infra/wordpress-infra
tofu destroy -auto-approve
```

**What Gets Deleted:**
- ✅ EC2 instance
- ✅ RDS database
- ✅ S3 bucket
- ✅ IAM roles/policies
- ✅ Security groups

**What Remains:**
- ✅ VPC (untouched)
- ✅ Subnets (untouched)
- ✅ Route53 zones (untouched)
- ✅ State file in S3 deleted, but free-tier state remains

**Result:** Clean app-level teardown. Network scaffold still available for next app.

---

### Scenario 2: Deploy Ghost on Same Network (FUTURE)

```bash
cd ../ghost-infra
terraform apply
```

Same resources created (EC2, RDS, S3, IAM), but for Ghost.

**Result:** Both WordPress and Ghost could run on same VPC.

---

### Scenario 3: Destroy Everything (FULL CLEANUP)

```bash
# 1. Destroy apps first
cd wordpress-infra && tofu destroy -auto-approve
cd ../ghost-infra && tofu destroy -auto-approve

# 2. Then destroy network
cd ../free-tier && tofu destroy -auto-approve
```

**What Gets Deleted:**
- ❌ All EC2 instances
- ❌ All RDS databases
- ❌ All S3 buckets
- ❌ VPC, subnets, security groups
- ❌ Route53 zones
- ❌ All state files

**Result:** Clean slate. All infrastructure removed.

---

## Cost Summary

### Before Free Tier Expires

| Phase | Resources | Monthly Cost |
|-------|-----------|--------------|
| free-tier | VPC + SGs + Route53 | $0.50 |
| wordpress-infra | EC2 + RDS + S3 + IAM | $0 |
| **Total** | | **$0.50** |

### After Free Tier Expires

| Phase | Resources | Monthly Cost |
|-------|-----------|--------------|
| free-tier | VPC + SGs + Route53 | $0.50 |
| wordpress-infra | EC2 + RDS + S3 + IAM | $15-20 |
| **Total** | | **$16-21** |

---

## Safety Checks

### Destroy Order (Important!)

✅ Always destroy in this order:
1. Applications (wordpress-infra, ghost-infra)
2. Network scaffold (free-tier)

❌ Do NOT destroy free-tier while apps are running (breaks dependencies)

### State Management

- Single S3 bucket: `tfstate-0001x`
- Separate state files per module
- DynamoDB locking prevents concurrent changes
- Versioning enabled (7-day retention)

### Rollback

If destroy fails, run with `-lock=false`:

```bash
tofu destroy -lock=false -auto-approve
```

---

## Testing Checklist

After deployment, verify:

- [ ] VPC created (free-tier)
- [ ] EC2 instance running (wordpress-infra)
- [ ] RDS database created (wordpress-infra)
- [ ] S3 bucket accessible (wordpress-infra)
- [ ] Security groups configured correctly
- [ ] SSH access to EC2 works
- [ ] Ansible can reach EC2
- [ ] Database connection works

After teardown, verify:

- [ ] wordpress-infra state deleted
- [ ] EC2 instance terminated
- [ ] RDS instance deleted
- [ ] S3 bucket deleted
- [ ] VPC still exists (free-tier)
- [ ] Route53 zones still exist

---

## Troubleshooting

### Destroy Fails with Lock Error

```bash
tofu force-unlock <LOCK_ID> -force
tofu destroy -lock=false -auto-approve
```

### State Corrupted

Use nuclear cleanup script:

```bash
cd ../..
./cleanup-nuclear.sh seldon us-east-2
```

### Need to Check What Would Be Destroyed

```bash
tofu plan -destroy
```

---

## Next Steps

1. ✅ Test Phase 1 deployment (free-tier) - DONE
2. ⏳ Test Phase 2 deployment (wordpress-infra)
3. ⏳ Verify Ansible can deploy WordPress to EC2
4. ⏳ Test App-level teardown
5. ⏳ Test Full cleanup

