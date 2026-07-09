# 🧪 Test Examples & Configuration Scenarios

This document shows all possible configurations for the CloudFront Blue-Green stack, organized in 3 main scenarios with progressively more features.

**All examples are production-ready and located in `/terraform/test-configs/`**

---

## 📋 Quick Reference

| Scenario | Tests | Use Case |
|----------|-------|----------|
| **Simple** | 1.1, 1.2, 1.3 | Static site, no rollback needed |
| **Blue-Green Rollback** | 2.1, 2.2, 2.3 | Need instant rollback capability |
| **Versioning** | 3.1, 3.2, 3.3 | Need to restore any historical version |

---

## 🟢 SCENARIO 1: Simple CloudFront + S3 (No Rollback)

Best for: Quick deployments, simple static sites, MVP testing

### Test 1.1: MVP Baseline
**File:** `test-1.1-simple-base.tfvars`

```hcl
region = "us-east-1"
buckets = [{
  name = "site-production"
  origin_access_control = true  # Private bucket (OAC)
  main_bucket = true
}]
cloudfront = {
  enabled = true
  aliases = []                   # No custom domain
  viewer_certificate = {
    cloudfront_default_certificate = true  # Use CloudFront default SSL
  }
}
lambda_edge = { enabled = false }           # No rollback needed
route53 = { enabled = false }               # No DNS
acm = { create = false }                    # No custom SSL
```

**What you get:**
- ✅ CloudFront distribution
- ✅ Private S3 bucket (OAC)
- ✅ HTTPS via CloudFront default certificate
- ✅ Default domain (e.g., `d1234xyz.cloudfront.net`)

**Deploy:**
```bash
terraform plan -var-file=terraform/test-configs/test-1.1-simple-base.tfvars
terraform apply -var-file=terraform/test-configs/test-1.1-simple-base.tfvars
```

---

### Test 1.2: MVP + Ordered Cache Behaviors
**File:** `test-1.2-simple-ordered-behaviors.tfvars`

```hcl
# Same as 1.1, but adds:
cloudfront = {
  # ... same as 1.1
  ordered_cache_behaviors = [{
    path_pattern = "/api/*"              # Match paths like /api/users, /api/data
    cached_methods = ["GET", "HEAD"]
    forwarded_values = {
      query_string = true                # Forward query strings (?key=value)
      cookies = { forward = "all" }      # Forward all cookies
    }
    default_ttl = 0                      # No caching for API calls
  }]
}
```

**What changes:**
- ✅ All of 1.1
- ✅ Path pattern `/api/*` with 0 TTL (no caching)
- ✅ Different caching rules for static vs API

**Use case:** Site with some API endpoints that shouldn't be cached

---

### Test 1.3: Full Simple Stack (SSL + Route53)
**File:** `test-1.3-simple-full-ssl-route53.tfvars`

```hcl
# Same as 1.2, but adds:
cloudfront = {
  aliases = ["www.0170170.xyz"]          # Custom domain
  viewer_certificate = {
    cloudfront_default_certificate = false  # Use custom SSL
  }
}
route53 = {
  enabled = true
  domain = "0170170.xyz"                 # Your domain
}
acm = {
  create = true                          # Create SSL certificate
  validation_method = "DNS"
}
```

**What changes:**
- ✅ All of 1.2
- ✅ Custom domain `www.0170170.xyz`
- ✅ SSL certificate from ACM
- ✅ Route53 alias record pointing to CloudFront

**Use case:** Production-ready simple site with custom domain and HTTPS

---

## 🔵 SCENARIO 2: Blue-Green with Instant Rollback

Best for: Production sites where you need instant rollback capability

### Test 2.1: Rollback Core (Lambda@Edge + SSM)
**File:** `test-2.1-rollback-base.tfvars`

```hcl
region = "us-east-1"
buckets = [
  {
    name = "site-production"
    origin_access_control = true
    main_bucket = true                  # Current live version
  },
  {
    name = "site-rollback"
    origin_access_control = true
    main_bucket = false                 # Previous version (standby)
  }
]
cloudfront = {
  # ... similar to 1.1 (no SSL, no Route53)
}
lambda_edge = {
  enabled = true                        # Enable toggle function
  cf_access_bucket_mode = "oac"         # Match bucket mode
}
```

**What you get:**
- ✅ 2 S3 buckets (production + rollback)
- ✅ Lambda@Edge function deployed
- ✅ SSM parameter for toggling
- ✅ CloudFront configured to use Lambda@Edge

**How it works:**
1. Deploy new version to `site-production` bucket
2. Keep old version in `site-rollback` bucket
3. If something breaks, set SSM parameter to toggle to rollback bucket
4. Lambda@Edge redirects CloudFront requests to the other bucket instantly

**Deploy & Test Rollback:**
```bash
# Deploy
terraform apply -var-file=terraform/test-configs/test-2.1-rollback-base.tfvars

# Deploy app to production bucket
aws s3 cp dist/ s3://site-production-xxxx/ --recursive

# Test it works
curl https://d1234xyz.cloudfront.net/

# NOW - Deploy new version to rollback bucket for next deploy
aws s3 cp dist-v2/ s3://site-rollback-xxxx/ --recursive

# If version 2 is bad, toggle rollback:
aws ssm put-parameter --name /Lambda/CF/Rollback --value "true" --overwrite

# Traffic instantly switches to rollback bucket (old version)
curl https://d1234xyz.cloudfront.net/  # Now serving from site-rollback

# Toggle back when fixed
aws ssm put-parameter --name /Lambda/CF/Rollback --value "false" --overwrite
```

---

### Test 2.2: Rollback + Ordered Cache Behaviors
**File:** `test-2.2-rollback-ordered-behaviors.tfvars`

```hcl
# Same as 2.1, but adds ordered cache behaviors:
cloudfront = {
  ordered_cache_behaviors = [{
    path_pattern = "/api/*"
    default_ttl = 0                     # API not cached
  }]
}
```

**What changes:**
- ✅ All of 2.1
- ✅ Path patterns work with rollback toggle
- ✅ Lambda@Edge applies to all paths

**Use case:** Rollback + dynamic content (API calls)

---

### Test 2.3: Full Rollback (SSL + Route53 + Ordered)
**File:** `test-2.3-rollback-full-ssl-route53.tfvars`

```hcl
# Same as 2.2, but adds:
cloudfront = {
  aliases = ["www.0170170.xyz"]
  viewer_certificate = {
    cloudfront_default_certificate = false
  }
}
route53 = {
  enabled = true
  domain = "0170170.xyz"
}
acm = {
  create = true
  validation_method = "DNS"
}
```

**What changes:**
- ✅ All of 2.2
- ✅ Custom domain with SSL
- ✅ Production-ready rollback configuration

**Use case:** Production site with instant rollback capability

---

## 📦 SCENARIO 3: Versioning with History Archive

Best for: Sites where you need to restore ANY historical version instantly

### Test 3.1: Versioning Base (3 Buckets)
**File:** `test-3.1-versioning-base.tfvars`

```hcl
region = "us-east-1"
buckets = [
  {
    name = "site-production"
    versioning = true                   # Track versions
    main_bucket = true
  },
  {
    name = "site-rollback"
    versioning = true
    main_bucket = false
  },
  {
    name = "site-versions"
    versioning = false
    versions_bucket = true              # Archives go here (.tar.gz)
  }
]
lambda_edge = {
  enabled = true
  cf_access_bucket_mode = "oac"
}
```

**What you get:**
- ✅ 3 S3 buckets (production + rollback + versions archive)
- ✅ S3 versioning enabled on main buckets
- ✅ Separate bucket for .tar.gz archives
- ✅ Ability to restore ANY historical version

**Versioning Workflow:**
```bash
# Deploy version 1
terraform apply -var-file=terraform/test-configs/test-3.1-versioning-base.tfvars
aws s3 cp dist-v1/ s3://site-production-xxxx/ --recursive

# For next deploy: Archive current version
tar -czf site-v1.tar.gz site/
aws s3 cp site-v1.tar.gz s3://site-versions-xxxx/

# Deploy version 2
aws s3 cp dist-v2/ s3://site-production-xxxx/ --recursive

# Problem found in v2? Restore v1:
# 1. Download archive
aws s3 cp s3://site-versions-xxxx/site-v1.tar.gz .
tar -xzf site-v1.tar.gz

# 2. Restore to production
aws s3 cp site/ s3://site-production-xxxx/ --recursive

# 3. Toggle Lambda if needed
aws ssm put-parameter --name /Lambda/CF/Rollback --value "true" --overwrite
```

---

### Test 3.2: Versioning + Ordered Cache Behaviors
**File:** `test-3.2-versioning-ordered-behaviors.tfvars`

```hcl
# Same as 3.1, but adds:
cloudfront = {
  ordered_cache_behaviors = [{
    path_pattern = "/api/*"
    default_ttl = 0
  }]
}
```

**Use case:** Versioning + dynamic content

---

### Test 3.3: Full Versioning (SSL + Route53)
**File:** `test-3.3-versioning-full-ssl-route53.tfvars`

```hcl
# Same as 3.2, but adds:
cloudfront = {
  aliases = ["www.0170170.xyz"]
  viewer_certificate = {
    cloudfront_default_certificate = false
  }
}
route53 = {
  enabled = true
  domain = "0170170.xyz"
}
acm = {
  create = true
  validation_method = "DNS"
}
```

**Use case:** Production site with versioning, SSL, custom domain, and instant rollback

---

## 🎯 Decision Matrix

Choose your scenario:

```
Do you need rollback?
├─ No  → SCENARIO 1 (Simple)
│       ├─ Need custom domain? → Test 1.3
│       ├─ Need API paths? → Test 1.2
│       └─ Just MVP? → Test 1.1
│
└─ Yes → Choose rollback style:
    ├─ Latest version only (current + previous) → SCENARIO 2 (Rollback)
    │   ├─ Need custom domain? → Test 2.3
    │   ├─ Need API paths? → Test 2.2
    │   └─ Just rollback? → Test 2.1
    │
    └─ All versions (keep history) → SCENARIO 3 (Versioning)
        ├─ Need custom domain? → Test 3.3
        ├─ Need API paths? → Test 3.2
        └─ Just versioning? → Test 3.1
```

---

## 📊 Feature Comparison

| Feature | 1.1 | 1.2 | 1.3 | 2.1 | 2.2 | 2.3 | 3.1 | 3.2 | 3.3 |
|---------|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| CloudFront | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| S3 (1 bucket) | ✅ | ✅ | ✅ | — | — | — | — | — | — |
| S3 (2 buckets) | — | — | — | ✅ | ✅ | ✅ | — | — | — |
| S3 (3 buckets) | — | — | — | — | — | — | ✅ | ✅ | ✅ |
| Rollback (toggle) | — | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Versioning | — | — | — | — | — | — | ✅ | ✅ | ✅ |
| Lambda@Edge | — | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Custom Domain | — | — | ✅ | — | — | ✅ | — | — | ✅ |
| SSL Certificate | — | — | ✅ | — | — | ✅ | — | — | ✅ |
| Route53 DNS | — | — | ✅ | — | — | ✅ | — | — | ✅ |
| Ordered Behaviors | — | ✅ | ✅ | — | ✅ | ✅ | — | ✅ | ✅ |

---

## 🚀 How to Deploy

### Step 1: Choose Your Test Config
Pick one from `/terraform/test-configs/` based on the matrix above.

### Step 2: Plan
```bash
terraform plan -var-file=terraform/test-configs/test-X.Y-name.tfvars
```

### Step 3: Apply
```bash
terraform apply -var-file=terraform/test-configs/test-X.Y-name.tfvars
```

### Step 4: Deploy Your App
```bash
cd bluegreen_site
npm run build
aws s3 cp dist/ s3://YOUR-BUCKET-NAME/ --recursive
```

### Step 5: Test
```bash
curl https://YOUR-CLOUDFRONT-URL/
# or open in browser
```

### Step 6: Cleanup
```bash
terraform destroy -var-file=terraform/test-configs/test-X.Y-name.tfvars
```

---

## 📖 Next Steps

- **Learn more variables:** See [`docs/full-guide.md`](./full-guide.md)
- **Understand architecture:** See [`docs/architecture.drawio`](../architecture.drawio)
- **Try the demo app:** See [`bluegreen_site/README.md`](../bluegreen_site/README.md)
- **Test different configs:** Mix and match variables from examples

---

## ❓ FAQ

**Q: Can I mix features from different tests?**
A: Yes! Use any test as a base and modify variables. The validation rules will catch incompatibilities.

**Q: Do I need all 3 buckets for versioning?**
A: Yes - production (live), rollback (standby), and versions (archives).

**Q: What happens if I change SSL settings?**
A: ACM certificate creation/deletion takes time. Plan accordingly.

**Q: Can I use S3 website mode instead of OAC?**
A: Yes, but change `origin_access_control = false` and `website = true`. Requires different Lambda@Edge template.

**Q: How long does Lambda@Edge take to deploy?**
A: 5-10 minutes for global replication. This is normal.

---

**Created:** 2026-07-09  
**Updated from:** Comprehensive Test Session - 9/9 tests validated
