# Approval Gates & Production Safety

## Overview

Three deployment strategies with flexible approval gates:

### Strategy 1: Auto-Deploy (Production-Safe)
- Trigger: Git push to main
- Approval: REQUIRED ✅
- Modules: All changed modules
- Use: Production deployments

### Strategy 2: Manual Dispatch (Developer-Friendly)
- Trigger: GitHub Actions UI
- Approval: SKIPPED
- Modules: Select specific ones
- Use: Development, testing, quick iterations

### Strategy 3: Three-Layer Approval (Maximum Safety)
1. **PR Review Approval** (Human review)
2. **CI Validation** (Automated checks)
3. **Production Deployment Approval** (Final gate before apply)

---

## Layer 1: Pull Request Review

**Purpose:** Code review before merge to main

**Setup in GitHub:**
1. Go to **Settings** → **Branches** → **main**
2. Enable **Require pull request reviews before merging**
3. Set **Required approving reviews: 1** (or more)
4. Enable **Require review from Code Owners** (if CODEOWNERS exists)
5. Enable **Dismiss stale pull request approvals when new commits are pushed**

**How it works:**
```
Branch: feature/improve-vpc
  ↓
Create PR
  ↓
CI validates (plan + lint) ✅
  ↓
Reviewer reviews changes
  ↓
Reviewer approves PR ✅
  ↓
Merge to main (button enabled)
  ↓
→ Triggers deployment workflow
```

---

## Layer 2: CI Validation

**Purpose:** Automated checks before human review

**Current workflow includes:**
- ✅ `tofu validate` (syntax check)
- ✅ `tofu plan` (show what changes)
- ✅ `tofu fmt -check` (code formatting)
- ✅ `tflint` (best practices)
- ✅ Cost estimation warnings

**Failure blocks merge:**
- If any check fails on PR, merge is blocked
- All checks must pass ✅
- Reviewers see full plan before approving

**Workflow status:**
```yaml
# PR checks (must pass)
plan:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'  # Only PRs
  steps:
    - tofu validate
    - tofu plan
    - tofu fmt -check
    - tflint

# Applies only on merge to main
apply:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

---

## Layer 3: Production Deployment Approval

**Purpose:** Final approval before infrastructure changes apply

**Setup in GitHub:**
1. Go to **Settings** → **Environments** → **production** (create if needed)
2. Check **"Require reviewers"**
3. Add approvers (yourself, team members, etc.)
4. Optional: Set **Deployment branches** to `main` only

**How it works:**
```
After merge to main:
  ↓
Workflow runs → hits approval job
  ↓
⏳ Waiting for approval (workflow paused)
  ↓
Approver checks Actions tab
  ↓
Approver clicks "Review Pending Deployments"
  ↓
Approver reviews changes + approves
  ↓
tofu apply runs ✅
  ↓
Infrastructure deployed
```

**Approver Instructions:**
1. Go to repo → **Actions** → latest workflow run
2. Look for **"Waiting for approval"** step in `approval` job
3. Click **"Review Pending Deployments"** button
4. Review infrastructure changes
5. Click **"Approve and Deploy"** or **"Reject"**
6. `tofu apply` proceeds if approved

---

## Comparison: Approval Strategies

| Strategy | Setup | Safety | Speed | Cost |
|----------|-------|--------|-------|------|
| **PR Review Only** | 5 min (GitHub UI) | Medium | Fast | Free |
| **PR + CI + Deploy Approval** | 10 min | High | Slower | Free |
| **Environment with Reviewers** | 5 min | High | Medium | Free |
| **Manual workflow_dispatch** | 15 min | High | Slowest | Free |

---

## Current Setup (Recommended)

### What's Enabled

✅ **Layer 1: PR Review** → Must configure in GitHub UI  
✅ **Layer 2: CI Validation** → Enabled in workflow  
✅ **Layer 3: Deploy Approval** → Enabled in workflow  

### Configuration Checklist

- [ ] **GitHub Branch Protection**
  - [ ] Enable "Require pull request reviews"
  - [ ] Set required reviewers: 1+
  - [ ] Dismiss stale approvals: Yes
  - Settings → Branches → main

- [ ] **GitHub Environment**
  - [ ] Create "production" environment
  - [ ] Enable "Require reviewers"
  - [ ] Add approvers (your GitHub username)
  - Settings → Environments → production

- [ ] **Workflow Validation**
  - [ ] Create test PR with small change
  - [ ] Verify CI runs (plan, lint, validate)
  - [ ] Approve PR
  - [ ] Merge to main
  - [ ] Check Actions tab for approval gate
  - [ ] Approve deployment
  - [ ] Verify tofu apply runs

---

## How to Trigger Approvals

### Scenario 1: Create a test PR

```bash
git checkout -b test/vpc-improvement
echo "# Test change" >> free-tier/main.tf
git commit -am "Test infrastructure change"
git push origin test/vpc-improvement
```

1. Open PR in GitHub
2. CI starts automatically (plan, lint)
3. Wait for CI to pass ✅
4. Reviewer approves PR
5. Merge to main
6. Check Actions tab for deployment approval
7. Click "Approve and Deploy"
8. Watch `tofu apply` run

### Scenario 2: Real deployment

Same flow, but with actual infrastructure changes.

---

## Approval Tips & Tricks

### Approving Deployments

When you see "Waiting for approval":

```
Your deployment is queued ⏳

Repository: ianlmk/aws-infra
Branch: main
Commit: abc1234

Review pending deployments
├── free-tier: vpc update (low risk)
├── wordpress-infra: rds scaling (medium risk)
└── ghost-infra: skipped (no changes)

[Approve and Deploy] [Reject]
```

**Checklist before approving:**
- ✅ Changes look correct (read plan summary)
- ✅ No unexpected resource deletion
- ✅ Cost impact acceptable (check estimation)
- ✅ Deployment time reasonable
- ✅ Time of day acceptable (not midnight?)

### Skipping Approval (Development Only)

If you need to skip approval for **development/testing only**:

```yaml
# NOT RECOMMENDED for production, but useful for testing
apply:
  needs: [detect-changes]  # Skip approval
  environment: null        # No approval gate
```

⚠️ **WARNING:** Only use for personal dev accounts. Never merge this to main.

### Automatic Rollback on Failure

If `tofu apply` fails:

```yaml
- name: Terraform Apply
  run: tofu apply -auto-approve
  continue-on-error: false  # Fail the job on apply error

- name: Notify on Failure
  if: failure()
  run: |
    echo "⚠️ Deployment failed!"
    echo "Rollback? Run: tofu destroy -auto-approve"
```

---

## Troubleshooting

### Approval Not Showing Up

**Problem:** Merged PR but no approval step appears

**Solution:**
1. Check environment exists: Settings → Environments → production
2. Check "Require reviewers" is enabled
3. Check approvers are listed
4. Run workflow again (make another PR)

### Approver Can't Find Deployment

**Problem:** Approver doesn't see deployment review button

**Solution:**
1. Check they have **write** access to repo
2. Approvers must be GitHub users in organization
3. Go to Actions → latest workflow run
4. Look for **"Waiting for approval"** step
5. Click **"Review Pending Deployments"** button

### Approval Expired

**Problem:** Deployment approval expired after 30 days

**Solution:**
1. Create new PR to trigger new deployment
2. Re-approve when prompted

---

## Multi-Environment Setup

For **dev, staging, production** environments:

```yaml
# Different approval rules per environment
deploy:
  environment:
    name: ${{ matrix.environment }}
  strategy:
    matrix:
      environment: [dev, staging, production]

# GitHub Setup:
# - dev: No reviewers (auto-deploy)
# - staging: 1 reviewer
# - production: 2 reviewers + security team
```

---

## Security Best Practices

1. **Require 2 approvals for production**
   - PR reviewer (code review)
   - Deployment approver (operational review)

2. **Use environment-based approval**
   - dev: Auto-approve (or no approval)
   - staging: 1 approver
   - production: 2+ approvers

3. **Review plan output before approving**
   - Never approve without reading changes
   - Watch for unintended deletions
   - Check cost estimates

4. **Limit approvers**
   - Only team members who understand infrastructure
   - Rotate who has approval rights
   - Audit approval history

5. **Use branch protection**
   - Require PR review before merge
   - Enforce CI passing
   - Dismiss stale approvals

---

## Approval Audit Trail

GitHub automatically records:
- ✅ Who approved deployment
- ✅ When approval happened
- ✅ What changes were deployed
- ✅ Deployment success/failure

**View approval history:**
1. Go to repo → **Actions** → workflow run
2. Check **"approval"** job for reviewer name
3. Timeline shows when approval happened

---

## Cost Impact

All approval methods: **$0/month**

- GitHub branch protection: Free
- GitHub environments: Free
- Approval workflow jobs: Free (public repo)

---

## Next Steps

1. **Setup GitHub branch protection** (5 min)
   - Settings → Branches → main
   - Require PR reviews + CI passing

2. **Setup production environment** (5 min)
   - Settings → Environments → production
   - Enable reviewers
   - Add yourself as approver

3. **Test workflow** (10 min)
   - Create PR
   - Review CI output
   - Merge PR
   - Approve deployment
   - Watch apply run

4. **Verify approval history**
   - Actions → workflow runs
   - Check "approval" job succeeded
   - Confirm tofu apply ran

Done! Production deployments now require approval. 🔒

---

## Workflow Dispatch - Manual Independent Deployments

### What is it?

`workflow_dispatch` allows you to manually trigger deployments **without approval** and **select specific modules** from the GitHub Actions UI.

### When to use

- **Development:** Test changes faster without approval delays
- **Module-specific:** Deploy only `wordpress-infra`, leave others untouched
- **Iteration:** Quickly test network changes without involving other modules
- **Hotfixes:** Deploy a specific fix without full stack deployment

### How to use

#### Step 1: Go to Actions tab
```
https://github.com/ianlmk/aws-infra/actions
```

#### Step 2: Select workflow
Click **"Terraform Plan & Apply"**

#### Step 3: Click "Run workflow"
Look for the **"Run workflow"** dropdown button on the right

#### Step 4: Select modules
```
☐ Deploy free-tier?
☐ Deploy wordpress-infra?
☐ Deploy ghost-infra?
```

Check the boxes for modules you want to deploy

#### Step 5: Click "Run workflow"
Workflow starts immediately, no approval needed

### Deployment modes

| Scenario | free-tier | wordpress | ghost | Use case |
|----------|-----------|-----------|-------|----------|
| Network only | ✅ | ❌ | ❌ | Test VPC changes |
| App only | ❌ | ✅ | ❌ | Update WordPress |
| Two modules | ✅ | ✅ | ❌ | Deploy network + app |
| All modules | ✅ | ✅ | ✅ | Full deployment |

### Example: Deploy WordPress only

```
Step 1: Actions > "Terraform Plan & Apply"
Step 2: Check ONLY "Deploy wordpress-infra?"
Step 3: Click "Run workflow"

Result:
  - free-tier: UNCHANGED
  - wordpress-infra: DEPLOYED ✅
  - ghost-infra: UNCHANGED
  
Time: ~15 minutes
Approval: NONE
```

### Comparison: Auto vs Manual

| Feature | Auto-Deploy | Manual Dispatch |
|---------|-------------|-----------------|
| Trigger | git push | Actions UI |
| Approval | ✅ Required | ❌ Skipped |
| Module selection | Auto-detected | Manual (checkboxes) |
| Best for | Production | Development |
| Safety | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Speed | Slow (approval) | Fast (immediate) |

### Workflow logic

#### Auto-Deploy (push to main)
```
git push → PR approval → CI validates → Approval gate → Apply (all modules)
```

#### Manual Dispatch (Actions UI)
```
Actions tab → Select modules → Run → Apply (selected only)
```

**Key difference:** Manual dispatch skips both PR review AND approval gate

### Safe practices

1. **Use for development only**
   - Development/staging: Use manual dispatch
   - Production: Use auto-deploy with approval

2. **Test one module first**
   - Don't deploy all 3 at once
   - Deploy free-tier first (lowest risk)
   - Then wordpress-infra

3. **Verify before applying**
   - Watch the apply job logs
   - Check outputs
   - Never auto-approve blind

4. **Use auto-deploy for critical changes**
   - Network restructuring: Use auto-deploy (approval)
   - Database migrations: Use auto-deploy (approval)
   - Quick fixes: Can use manual dispatch

### Error handling

**Error: "No modules selected for deployment"**
- You clicked "Run workflow" without checking any modules
- Fix: Check at least one module, try again

**Error: "Deployment failed"**
- tofu apply encountered an error
- Fix: Check logs, fix issue, try manual dispatch again
- Consider: Use auto-deploy for critical changes (forces PR review)

### Rollback

If deployment goes wrong:

**Manual dispatch (quick rollback):**
```bash
cd module-that-broke
tofu destroy  # Local destroy
```

**Auto-deploy (use git + approval):**
```bash
git revert commit-hash  # Create new PR
# Go through approval process
# Deploy fix via auto-deploy
```

---

## When to use each deployment mode

### Use Auto-Deploy (approval required) when:
- ✅ Production infrastructure
- ✅ Network changes (might affect all apps)
- ✅ Database migrations
- ✅ Security-related changes
- ✅ Team deployments (need code review)

### Use Manual Dispatch (no approval) when:
- ✅ Development environment
- ✅ Testing infrastructure changes
- ✅ Single module updates
- ✅ Quick iterations (fast feedback loop)
- ✅ Personal dev account (no team approval)

---

**Remember:** Two deployment modes for maximum flexibility!

- **Production:** Auto-deploy with approval ✅
- **Development:** Manual dispatch, select modules ⚡
