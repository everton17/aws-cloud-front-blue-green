# 🤖 GitHub Actions Workflow Generator Module

This Terraform module auto-generates GitHub Actions workflows based on your deployment modality and configures OIDC authentication for keyless AWS access.

---

## What This Module Does

1. **Reads your `workflow_option`** to determine which workflows to generate
2. **Creates OIDC trust relationship** between GitHub and AWS
3. **Generates IAM roles** with least-privilege scoped to your resources
4. **Creates `.github/workflows/` files** with ready-to-use workflows
5. **Configures GitHub Actions** to authenticate via OIDC (no long-lived keys)

---

## Workflows Generated

Based on `workflow_option`, different workflows are created:

### `simple-deploy`
```
.github/workflows/
└── deploy.yml  (Build → Upload → Invalidate)
```

### `deploy-and-rollback`
```
.github/workflows/
├── deploy.yml  (Build → Upload → Invalidate)
└── rollback.yml  (Toggle SSM → Invalidate)
```

### `deploy-rollback-and-restore`
```
.github/workflows/
├── deploy.yml  (Build → Upload → Archive → Invalidate)
├── rollback.yml  (Toggle SSM → Invalidate)
└── rollback-and-restore.yml  (Restore version → Invalidate)
```

---

## Configuration

In your `terraform.tfvars`:

```hcl
gha_gen_workflows = {
  enabled            = true                              # Generate workflows?
  github_org         = "your-github-org"                 # Your GitHub organization
  github_repo        = "your-repo-name"                  # Your repository name
  role_name          = "github-actions-deploy"           # IAM role name
  workflow_option    = "deploy-and-rollback"             # Which workflows to generate
  deploy_branch      = "main"                            # Trigger on push to this branch
  build_command      = "cd ./bluegreen_site && npm run build"  # Your build command
  build_output_dir   = "./bluegreen_site/dist"           # Where build output goes
  workflows_output_path = ".github/workflows"            # Where workflows are written
}
```

---

## OIDC Authentication

### How It Works

1. **Trust Relationship:** GitHub Actions ↔ AWS IAM (via OIDC provider)
2. **Token Generation:** GitHub generates a JWT token for each workflow run
3. **AWS Exchange:** Workflow exchanges JWT for temporary AWS credentials
4. **Least Privilege:** IAM role scoped to only needed resources

### Security Benefits

✅ **No long-lived AWS keys** stored in GitHub  
✅ **No AWS credentials in repository**  
✅ **Automatic credential rotation** (each run gets new credentials)  
✅ **Audit trail** - each action is traceable to specific run  
✅ **Least-privilege access** - role only has permissions for deployed resources  

---

## Workflow Templates

Templates are located in `modules/gha_gen_workflows/templates/`:

- `deploy.yml.tpl` - Main deployment workflow
- `rollback.yml.tpl` - Rollback workflow
- `rollback-and-restore.yml.tpl` - Version restore workflow

Each template is customized with variables from your `terraform.tfvars`.

---

## IAM Permissions

The generated IAM role includes least-privilege permissions for:

- **S3:** `PutObject`, `DeleteObject` on your buckets
- **CloudFront:** `CreateInvalidation` on your distribution
- **SSM:** `PutParameter`, `GetParameter` for rollback toggle
- **ECR (if applicable):** `GetAuthorizationToken`

**Never:** `DeleteBucket`, `DeleteDistribution`, `DeleteRole`, or other destructive operations.

---

## Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `enabled` | bool | No | Enable workflow generation (default: true) |
| `generate_workflows` | bool | No | Generate GitHub Actions workflows (default: true) |
| `github_org` | string | Yes | GitHub organization name |
| `github_repo` | string | Yes | GitHub repository name |
| `role_name` | string | No | IAM role name (default: `github-actions-deploy`) |
| `workflow_option` | string | Yes | Which workflows: `simple-deploy`, `deploy-and-rollback`, `deploy-rollback-and-restore` |
| `deploy_branch` | string | No | Trigger workflows on push to this branch (default: `main`) |
| `build_command` | string | Yes | Command to build your app (e.g., `npm run build`) |
| `build_output_dir` | string | Yes | Directory containing build output (e.g., `dist/`) |
| `workflows_output_path` | string | No | Where to write workflows (default: `.github/workflows`) |

---

## Outputs

| Output | Description |
|--------|-------------|
| `github_oidc_provider_arn` | ARN of GitHub OIDC provider |
| `github_actions_role_arn` | ARN of generated GitHub Actions IAM role |
| `github_actions_role_name` | Name of generated GitHub Actions IAM role |

---

## Example Usage

### Minimal

```hcl
module "gha_gen_workflows" {
  source = "./modules/gha_gen_workflows"
  
  github_org   = "my-org"
  github_repo  = "my-repo"
  workflow_option = "deploy-and-rollback"
  build_command = "npm run build"
  build_output_dir = "dist"
  s3_main_bucket_name = aws_s3_bucket.main.id
  cloudfront_distribution_id = aws_cloudfront_distribution.this.id
  s3_rollback_bucket_name = aws_s3_bucket.rollback.id
}
```

### Full

```hcl
module "gha_gen_workflows" {
  source = "./modules/gha_gen_workflows"
  
  enabled              = true
  generate_workflows   = true
  github_org           = "everton17"
  github_repo          = "aws-cloud-front-blue-green"
  role_name            = "github-actions-deploy-role"
  workflow_option      = "deploy-rollback-and-restore"
  deploy_branch        = "main"
  build_command        = "cd ./bluegreen_site && npm run build"
  build_output_dir     = "./bluegreen_site/dist"
  workflows_output_path = ".github/workflows"
  s3_main_bucket_name  = aws_s3_bucket.main.id
  s3_rollback_bucket_name = aws_s3_bucket.rollback.id
  s3_versions_bucket_name = aws_s3_bucket.versions.id
  cloudfront_distribution_id = aws_cloudfront_distribution.this.id
  ssm_parameter_name   = "/Lambda/CF/Rollback"
  aws_account_id       = data.aws_caller_identity.current.account_id
  aws_region           = var.region
}
```

---

## Common Issues

### Workflows Not Generated

Check:
- `generate_workflows = true` in module call
- `terraform apply` was run (not just `plan`)
- `.github/workflows/` directory was created

### OIDC Authentication Fails

Check:
- GitHub repository matches configured `github_repo`
- IAM role exists: `aws iam get-role --role-name github-actions-deploy`
- Trust relationship includes your GitHub organization

### Workflows Regenerated After Apply

**This is expected behavior.** Every `terraform apply` regenerates workflows from templates. This ensures your workflows always match your Terraform configuration.

If you need custom workflow behavior:
1. Edit the template files (not the generated `.github/workflows/` files)
2. Run `terraform apply` to regenerate
3. The generated files will reflect your template changes

---

## Related Documentation

- [Workflows Guide](../../docs/en/WORKFLOWS.md) - How to use generated workflows
- [DEMO Guide](../../docs/en/DEMO.md) - Testing workflows
- [Full Configuration Guide](../../docs/en/full-guide.md) - Complete module reference
