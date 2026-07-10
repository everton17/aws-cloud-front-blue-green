# 🚀 CloudFront Blue-Green Stack - Demo Guide

This guide walks through rapid demonstrations of the three deployment stacks using pre-configured tfvars files.

---

## 📋 Quick Reference

| Demo | File | Time | Features | Cost |
|------|------|------|----------|------|
| **Simple** | `terraform-simple-demo.tfvars` | 5 min | CloudFront + S3 | ~$0.50-2/mo |
| **Rollback** | `terraform-rollback-demo.tfvars` | 8 min | + Lambda@Edge + Blue/Green | ~$2-5/mo |
| **Versioning** | `terraform-versioning-demo.tfvars` | 10 min | + Version Archive + Restore | ~$3-8/mo |

---

## 🟢 DEMO 1: Simple Stack (5 minutes)

**What you'll see:** Basic CloudFront + S3 deployment  
**Perfect for:** Understanding the fundamentals

### Setup & Deploy

```bash
# Plan the infrastructure
terraform plan -var-file=terraform-simple-demo.tfvars -out=simple.plan

# Apply
terraform apply simple.plan

# Deploy the demo app
cd bluegreen_site && npm run build
aws s3 cp dist/ s3://demo-site-production-*/ --recursive --profile default

# Test
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl -I https://$DOMAIN/
```

### What to Show

- ✅ CloudFront distribution created
- ✅ S3 bucket with OAC (private access)
- ✅ Custom error responses (404 → index.html for SPA support)
- ✅ Cache behaviors (API paths with different TTL)

---

## 🔵 DEMO 2: Blue-Green Rollback (8 minutes)

**What you'll see:** Instant rollback capability  
**Perfect for:** Showing zero-downtime deployments

### Setup & Deploy

```bash
# Plan and apply rollback stack
terraform plan -var-file=terraform-rollback-demo.tfvars -out=rollback.plan
terraform apply rollback.plan

# Deploy version 1
cd bluegreen_site && npm run build
aws s3 cp dist/ s3://demo-site-green-*/ --recursive

# Get domain
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl https://$DOMAIN/ | grep VERSION

# Deploy version 2 (prepare for rollback)
echo "<h1>VERSION 2 - LIVE!</h1>" > src/index.html
npm run build
aws s3 cp dist/ s3://demo-site-green-*/ --recursive

# Copy v1 to rollback bucket
aws s3 cp dist-old/ s3://demo-site-blue-*/ --recursive
```

### ✨ Instant Rollback

```bash
# Toggle to previous version
aws ssm put-parameter --name "/BlueGreen/Rollback" --value "true" --overwrite

# Wait ~60 seconds for Lambda cache TTL
sleep 60

# Verify rollback (now serving version 1)
curl https://$DOMAIN/ | grep VERSION
# Shows "VERSION 1" content - INSTANT ROLLBACK! 🎉

# Toggle back
aws ssm put-parameter --name "/BlueGreen/Rollback" --value "false" --overwrite
```

### Key Talking Points

> "This is zero-downtime deployment. Instead of rebuilding on rollback, we toggle an SSM parameter that Lambda@Edge reads. The switch happens instantly, and the previous version is already warm in the blue bucket."

---

## 📦 DEMO 3: Versioning with Archive (10 minutes)

**What you'll see:** Full version history + restore any version  
**Perfect for:** Showing enterprise-grade disaster recovery

### Setup & Deploy

```bash
# Plan and apply versioning stack
terraform plan -var-file=terraform-versioning-demo.tfvars -out=versioning.plan
terraform apply versioning.plan

# Deploy version 1
cd bluegreen_site && npm run build
COMMIT_V1=$(git rev-parse --short HEAD)

# Archive version 1
tar -czf /tmp/version-$COMMIT_V1.tar.gz dist/
aws s3 cp /tmp/version-$COMMIT_V1.tar.gz s3://demo-site-versions-*/

# Deploy to production
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
DOMAIN=$(terraform output -raw cloudfront_distribution_domain)
curl https://$DOMAIN/

# Deploy version 2
echo "<h1>VERSION 2</h1>" > src/index.html
npm run build
COMMIT_V2=$(git rev-parse --short HEAD)

# Archive and deploy v2
tar -czf /tmp/version-$COMMIT_V2.tar.gz dist/
aws s3 cp /tmp/version-$COMMIT_V2.tar.gz s3://demo-site-versions-*/
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
```

### Rollback & Restore

```bash
# Instant rollback to v1
aws ssm put-parameter --name "/Versioning/Rollback" --value "true" --overwrite
sleep 60
curl https://$DOMAIN/ | grep VERSION  # Shows v1

# Restore specific version (v2)
aws s3 cp s3://demo-site-versions-*/version-$COMMIT_V2.tar.gz /tmp/
tar -xzf /tmp/version-$COMMIT_V2.tar.gz
aws s3 cp dist/ s3://demo-site-production-*/ --recursive
aws ssm put-parameter --name "/Versioning/Rollback" --value "false" --overwrite

# List available versions
aws s3 ls s3://demo-site-versions-*/
```

### Key Talking Points

> "Production-grade deployment: rollback instantly AND restore any historical version from the complete archive. Every build is archived with its commit SHA, so you always have a backup."

---

## 🎯 Full Demo Sequence (30 minutes)

Run all three demos back-to-back to show the progression:

```bash
# Demo 1: Simple (5 min)
terraform apply -var-file=terraform-simple-demo.tfvars -auto-approve
# ... follow Demo 1 flow ...
terraform destroy -var-file=terraform-simple-demo.tfvars -auto-approve

# Demo 2: Rollback (8 min)
terraform apply -var-file=terraform-rollback-demo.tfvars -auto-approve
# ... follow Demo 2 flow ...
terraform destroy -var-file=terraform-rollback-demo.tfvars -auto-approve

# Demo 3: Versioning (10 min)
terraform apply -var-file=terraform-versioning-demo.tfvars -auto-approve
# ... follow Demo 3 flow ...
terraform destroy -var-file=terraform-versioning-demo.tfvars -auto-approve
```

---

## 💡 Pro Tips

- **Show the AWS Console:** Open CloudFront, S3, Lambda, SSM in browser tabs
- **Time the rollback:** Show the instant switch (< 60s)
- **Lambda@Edge deployment:** Normal - can take 5-10 minutes to replicate globally
- **S3 eventual consistency:** Use `--region us-east-1` explicitly if needed

---

## ✅ Demo Checklist

- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] GitHub token set (if testing workflows)
- [ ] `terraform init` completed
- [ ] bluegreen_site dependencies installed (`npm install`)
- [ ] CloudFront domain noted

---

## 📊 Cleanup & Cost

After demos, remove all resources:

```bash
for config in terraform-simple-demo.tfvars terraform-rollback-demo.tfvars terraform-versioning-demo.tfvars; do
  terraform destroy -var-file=$config -auto-approve 2>/dev/null || true
done
```

**Cost per 10-minute demo:** ~$0.10-0.62 (depends on Lambda@Edge usage)

---

## 🎓 Learning Outcomes

After running these three demos, you'll understand: basic CloudFront deployment (Simple), zero-downtime deployments with instant rollback (Rollback), and full version history with disaster recovery (Versioning).

---

**See also:** [Workflows Guide](./WORKFLOWS.md) | [Full Configuration Guide](./full-guide.md)
