#-----------#
# Kill Switch Patterns #
#-----------#

Quick ways to shut down and avoid charges.

## Option 1: Kill One App (Fastest)

```bash
cd ~/workspace/seldon/aws-infra/free-tier

# Comment out the app in tfvars
cat free-tier.auto.tfvars | sed 's/^networks = {/"ghost" = {/g'

# Then apply (destroys ghost app only)
AWS_PROFILE=opentofu ~/.local/bin/tofu apply

# Cost after: $0.50/month (Route53 zone)
```

## Option 2: Selective Destruction

Destroy web server but keep database:

```bash
export TF_VAR_databases='...'  # Still set this
web_servers = {}               # Empty = destroy

tofu apply
```

Destroy database but keep web server:

```bash
databases = {}  # Empty = destroy
tofu apply
```

## Option 3: Full Nuclear (Destroy Everything)

```bash
cd ~/workspace/seldon/aws-infra/free-tier

# Remove all app configs
cat > /tmp/empty.tfvars << EOF
networks = {}
web_servers = {}
databases = {}
storage_buckets = {}
dns_records = {}
EOF

AWS_PROFILE=opentofu ~/.local/bin/tofu apply -var-file=/tmp/empty.tfvars

# Cost after: $0.50/month (Route53 zone only)
```

Or direct destruction:

```bash
AWS_PROFILE=opentofu ~/.local/bin/tofu destroy -auto-approve
```

**Warning:** This destroys EVERYTHING. RDS will create a final snapshot (saves data, but can take time).

## Option 4: Progressive Shutdown (Recommended)

Smart teardown order:

```bash
cd ~/workspace/seldon/aws-infra/free-tier

# 1. Destroy DNS records (optional)
AWS_PROFILE=opentofu ~/.local/bin/tofu apply -target='aws_route53_record' -auto-approve

# 2. Destroy web servers
AWS_PROFILE=opentofu ~/.local/bin/tofu apply -target='module.web_server' -auto-approve

# 3. Destroy storage (optional)
AWS_PROFILE=opentofu ~/.local/bin/tofu apply -target='module.storage' -auto-approve

# 4. Destroy database (creates final snapshot)
AWS_PROFILE=opentofu ~/.local/bin/tofu apply -target='module.database' -auto-approve

# 5. Destroy network
AWS_PROFILE=opentofu ~/.local/bin/tofu apply -target='module.network' -auto-approve

# Keep: IAM, Route53 zone (~$0.50/month)
```

## Option 5: Stop, Don't Destroy (Cheapest Pause)

If you might run again soon:

```bash
# AWS Console → EC2 → Instances → Select ghost instance → Instance State → Stop

# AWS Console → RDS → Databases → Select ghost-mysql → Instance Actions → Stop

# Cost: $0 (stopped instances don't charge, EIP still $3.50/month if allocated)

# To resume:
# EC2: Instance State → Start
# RDS: Instance Actions → Start
```

## Option 6: Automation with Variable Toggles

Create a `.tfvars` file for "minimal" state:

```bash
# minimal.tfvars
networks = {}
web_servers = {}
databases = {}
storage_buckets = {}
dns_records = {}

# iam_users, route53_zones stay (required)
```

Then:

```bash
# Kill everything
tofu apply -var-file=minimal.tfvars

# Resurrect everything
tofu apply -var-file=free-tier.auto.tfvars
```

## Cost Comparison

| State | Monthly Cost | Time to Deploy | Use Case |
|-------|--------------|----------------|----------|
| **Running** | $0.50-70 | N/A | Production-like |
| **Stopped** (EC2+RDS) | $3.50 | Seconds to resume | Pause development |
| **Destroyed** | $0.50 | 10-15 min to redeploy | Long break |
| **Completely gone** | $0 | Delete Route53 zone too | Nuke it |

## Recommended Workflow

### Development Session
```bash
# Start of day
tofu apply  # Deploy using free-tier.auto.tfvars

# Work...

# End of day (keep VPC warm)
echo "Shutting down..."
tofu apply -var-file=minimal.tfvars
# Cost for night: $0.50/month
```

### Before Vacation (2+ weeks away)
```bash
tofu apply -var-file=minimal.tfvars
# Cost: $0.50/month
# Redeploy time: 15 minutes
```

### After Vacation (3+ months away)
```bash
tofu destroy -auto-approve  # Remove everything including VPC
# Cost: $0
# Redeploy time: 20 minutes
```

## Destroy Gotchas

### RDS Final Snapshot
```bash
# RDS creates a final snapshot on destroy
# ✅ Good: Data is safe
# ⏱ Takes 5-10 minutes
# 💾 Snapshots cost ~$0.023/GB/month (but free tier has 20GB free)

# To skip snapshot (dev only):
skip_final_snapshot = true
```

### Elastic IPs
```bash
# If you destroy before releasing EIP:
# 1. EIP is still allocated
# 2. Costs $3.50/month until manually released

# Prevention:
eip_allocation = false  # Or release in console before destroy
```

### Route53 Zone
```bash
# Route53 zone is NOT destroyed by "tofu destroy"
# Must manually delete in AWS Console
# Cost: $0.50/month

# To include in destroy: add to tfvars lifecycle
```

## Check Costs Before/After

```bash
# See what will change
tofu plan

# See actual spend
# AWS Console → Billing Dashboard → Cost Explorer
# Filter by date and service
```

## Emergency Kill

If something is charging unexpectedly:

```bash
# 1. Check what's running
AWS_PROFILE=opentofu aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

AWS_PROFILE=opentofu aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' --output table

# 2. Stop immediately
AWS_PROFILE=opentofu aws ec2 stop-instances --instance-ids i-xxxxx
AWS_PROFILE=opentofu aws rds stop-db-instance --db-instance-identifier ghost-mysql

# 3. Then plan teardown
tofu plan -destroy
tofu destroy
```

---

**Key:** You can go from $0.50/month to fully destroyed in <5 minutes. Or pause with stopped instances. Choose based on how long you'll be away.
