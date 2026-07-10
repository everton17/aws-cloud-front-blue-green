# 🤖 GitHub Actions Workflows Guide

This guide explains how GitHub Actions workflows are auto-generated and their role in the deployment stack.

---

## 📋 Quick Reference

| Workflow | Modality | Purpose | Trigger |
|----------|----------|---------|---------|
| `deploy.yml` | All | Build, upload, invalidate cache | Push to main |
| `rollback.yml` | Rollback, Versioning | Toggle SSM, invalidate cache | Manual |
| `rollback-and-restore.yml` | Versioning | Restore specific version | Manual + SHA param |

---

## How Workflows Are Generated

### The Generation Process

1. **You configure `workflow_option` in terraform.tfvars:**
   ```hcl
   gha_gen_workflows = {
     workflow_option = "simple-deploy"  # or "deploy-and-rollback" or "deploy-rollback-and-restore"
   }
   ```

2. **Terraform module `gha_gen_workflows` reads your choice:**
   - Selects which workflows to generate
   - Creates IAM roles and OIDC trust relationships
   - Generates workflow YAML files

3. **Files are created in `.github/workflows/`:**
   ```
   .github/workflows/
   ├── deploy.yml (always generated)
   ├── rollback.yml (if rollback modality)
   └── rollback-and-restore.yml (if versioning modality)
   ```

4. **You commit and push:**
   ```bash
   git add .github/workflows/
   git commit -m "ci: add generated deployment workflows"
   git push origin main
   ```

### Workflows per Modality

| `workflow_option` | Modality | Workflows Generated |
|-------------------|----------|-------------------|
| `simple-deploy` | Simple | • `deploy.yml` |
| `deploy-and-rollback` | Rollback | • `deploy.yml`<br>• `rollback.yml` |
| `deploy-rollback-and-restore` | Versioning | • `deploy.yml`<br>• `rollback.yml`<br>• `rollback-and-restore.yml` |

---

## 🚀 deploy.yml

**When it's generated:** Always (all modalities)

### What it does:
1. Build your app (`npm run build`)
2. Upload to S3 production bucket
3. Copy previous version to rollback bucket (if Rollback/Versioning)
4. Archive version (if Versioning)
5. Invalidate CloudFront cache
6. Reset SSM parameter to `false` (if Rollback/Versioning)

### Trigger:
```bash
# Automatic: Push to main branch
git push origin main

# Manual: Run workflow
gh workflow run deploy.yml
```

### Authentication:
Uses OIDC (no long-lived AWS keys). GitHub → AWS trust relationship configured by Terraform.

### Timing:
~2-3 minutes per deploy

---

## 🔄 rollback.yml

**When it's generated:** Rollback and Versioning modalities only

### What it does:
1. Toggle SSM parameter from `false` → `true`
2. Invalidate CloudFront cache
3. Lambda@Edge detects toggle within ~60 seconds
4. Traffic switches to rollback (blue) bucket

### Trigger:
```bash
# Manual: Run rollback workflow
gh workflow run rollback.yml

# Or: GitHub Actions UI → rollback.yml → Run workflow
```

### Result:
Previous version is instantly live. No rebuild, no re-upload.

### Timing:
~30 seconds

---

## 🔌 rollback-and-restore.yml

**When it's generated:** Versioning modality only

### What it does:
1. Accept version SHA as input parameter
2. Download archive from S3 versions bucket
3. Extract and upload to production bucket
4. Toggle SSM if needed
5. Invalidate CloudFront cache

### Trigger:
```bash
# Get available versions
aws s3 ls s3://demo-site-versions-*/

# Restore specific version by SHA
gh workflow run rollback-and-restore.yml \
  -f version_sha=abc123def456

# Or: GitHub Actions UI → rollback-and-restore.yml → input SHA
```

### Example:
```bash
# If you want to restore a version from commit abc123
gh workflow run rollback-and-restore.yml -f version_sha=abc123
# Workflow downloads version-abc123.tar.gz, extracts, uploads to production
```

### Timing:
~1-2 minutes

---

## ⚠️ Important: Don't Edit Workflows Manually

**Workflows are regenerated every time you run `terraform apply`.**

```bash
terraform apply -var-file=terraform.tfvars
# This OVERWRITES .github/workflows/ with regenerated versions
```

### Customization Strategy

If you need to customize a workflow:

1. **Edit the template** in `modules/gha_gen_workflows/templates/`
2. **Don't edit** the generated `.github/workflows/*.yml` files
3. **Run terraform apply** to regenerate with your changes

See [gha_gen_workflows README](../../modules/gha_gen_workflows/README.md) for template details.

---

## 🔐 Authentication & Permissions

All workflows use **OIDC (OpenID Connect)** for AWS authentication:

- ✅ **No long-lived AWS keys stored** in GitHub
- ✅ **Least-privilege IAM role** per modality
- ✅ **Automatic token generation** per workflow run
- ✅ **Scoped to specific AWS resources** (buckets, CloudFront, SSM)

Configured automatically by the `gha_gen_workflows` module.

---

## Workflow Execution Flow

```
┌─────────────────┐
│   Git Event     │
├─────────────────┤
│ Push to main OR │
│ Manual trigger  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  GitHub Actions Job Starts      │
├─────────────────────────────────┤
│ 1. Assume IAM role via OIDC     │
│ 2. Build application            │
│ 3. Upload to AWS (S3/SSM)       │
│ 4. Invalidate CloudFront cache  │
└────────┬────────────────────────┘
         │
         ▼
    ✅ Success
    (Lambda@Edge applies changes within ~60s)
```

---

## Troubleshooting

### Workflow doesn't start after push
- Check branch: workflows only trigger on `main` (default)
- Change: edit `gha_gen_workflows.deploy_branch` in terraform.tfvars

### OIDC authentication fails
- Verify IAM role exists: `aws iam get-role --role-name github-actions-deploy`
- Check trust relationship in AWS console

### Rollback doesn't work
- Verify SSM parameter: `aws ssm get-parameter --name /Lambda/CF/Rollback`
- Wait 60s: Lambda@Edge cache TTL
- Check CloudFront invalidation status

### Lambda@Edge changes not visible
- Lambda@Edge takes 5-10 minutes to replicate globally
- This is normal AWS behavior

---

## Examples

### Simple workflow run (Deploy)
```bash
# Automatic on push
git push origin main

# Or manual
gh workflow run deploy.yml

# Check status
gh run list --workflow deploy.yml
```

### Rollback example
```bash
# Something breaks in production...
gh workflow run rollback.yml

# Traffic switches to previous version instantly
# Users don't see any downtime
```

### Restore specific version example
```bash
# You want to go back to commit abc123
gh workflow run rollback-and-restore.yml -f version_sha=abc123

# Workflow restores that exact version
```

---

## Related Documentation

- [DEMO Guide](./DEMO.md) - How to test workflows
- [Full Configuration](./full-guide.md) - All variable options
- [gha_gen_workflows Module](../../modules/gha_gen_workflows/README.md) - Module internals
