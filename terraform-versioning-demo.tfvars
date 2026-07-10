# ============================================================================
# DEMO 3: VERSIONING STACK - Full History + Instant Rollback
# ============================================================================
# This configuration adds complete version management:
# - THREE S3 buckets (production + rollback + versions archive)
# - Lambda@Edge for instant switching between green/blue
# - .tar.gz archives of every build in separate bucket
# - Ability to restore ANY historical version by commit SHA
# - Perfect for: Mission-critical apps, audit requirements, disaster recovery
#
# Estimated cost: ~$3-8/month (CloudFront + 3x S3 + Lambda@Edge + SSM)
# Deploy time: ~10 minutes (includes archive creation)
# Demo: Deploy v1 → Deploy v2 → Test → Rollback → Restore v1
# ============================================================================

region = "us-east-1"

# THREE buckets: production (main) + rollback (standby) + versions (archive)
buckets = [
  {
    name                  = "demo-site-production"     # Current live version (GREEN)
    force_destroy         = true
    versioning            = true                       # Track S3 object versions
    website               = false
    origin_access_control = true
    main_bucket           = true                       # This is production
    index_document        = "index.html"
    error_document        = "index.html"
  },
  {
    name                  = "demo-site-rollback"       # Previous version (BLUE)
    force_destroy         = true
    versioning            = true                       # Track S3 object versions
    website               = false
    origin_access_control = true
    main_bucket           = false                      # This is standby/rollback
    index_document        = "index.html"
    error_document        = "index.html"
  },
  {
    name                  = "demo-site-versions"       # Version archives (.tar.gz)
    force_destroy         = true
    versioning            = false                      # No need to version archives
    website               = false
    origin_access_control = true                       # Required by validation (not actually used for versions bucket)
    main_bucket           = false                      # Not a production bucket
    versions_bucket       = true                       # This stores archives
  }
]

cloudfront = {
  enabled             = true
  default_root_object = "index.html"

  # Adding custom domain for production-like demo
  aliases = []        # Set to ["your-domain.com"] if you have one

  default_cache_behavior = {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    forwarded_values = {
      query_string = false
      cookies = {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Comprehensive cache behaviors for production scenario
  ordered_cache_behaviors = [
    {
      path_pattern    = "/api/*"                      # Dynamic content
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods  = ["GET", "HEAD"]
      forwarded_values = {
        query_string = true
        cookies = {
          forward = "all"                             # Forward auth cookies
        }
      }
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    },
    {
      path_pattern    = "/static/*"                   # Immutable static assets
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      forwarded_values = {
        query_string = false
        cookies = {
          forward = "none"
        }
      }
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 31536000               # 1 year
      max_ttl                = 31536000
    },
    {
      path_pattern    = "/*.html"                     # HTML files: short cache
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      forwarded_values = {
        query_string = false
        cookies = {
          forward = "none"
        }
      }
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 300                    # 5 minutes (for quick demo feedback)
      max_ttl                = 3600
    }
  ]

  restrictions = {
    geo_restriction = {
      restriction_type = "none"
    }
  }

  custom_error_response = [
    {
      error_code            = 404
      response_page_path    = "/index.html"
      response_code         = 200
      error_caching_min_ttl = 30
    }
  ]

  viewer_certificate = {
    cloudfront_default_certificate = true             # Demo with default cert
  }
}

# Lambda@Edge ENABLED - Full blue/green + versioning support
lambda_edge = {
  enabled               = true
  cf_access_bucket_mode = "oac"                       # Private buckets
  function_name         = "cloudfront-versioning-toggle"
  parameter_store_name  = "/Versioning/Rollback"
  handler               = "index.handler"
  runtime               = "nodejs20.x"
}

# Route53 DISABLED - using CloudFront default domain for simplicity
# In production, you'd enable this with your domain
route53 = {
  enabled = false
  # domain = "your-domain.com"    # Uncomment if you have a domain
}

# ACM DISABLED - using CloudFront default certificate
# In production with custom domain, enable ACM
# When using cloudfront_default_certificate = true, must explicitly set create = false
acm = {
  create = false
}

# GitHub Actions workflows - generates deploy and rollback-and-restore workflows
gha_gen_workflows = {
  enabled             = true
  github_org          = "everton17"
  github_repo         = "aws-cloud-front-blue-green"
  role_name           = "github-actions-deploy"
  workflow_option     = "deploy-rollback-and-restore"  # Full versioning workflows
  deploy_branch       = "main"
  build_command       = "cd ./bluegreen_site && npm run build"
  build_output_dir    = "./bluegreen_site/dist"
}

# ============================================================================
# DEMO WORKFLOW FOR THIS STACK:
# ============================================================================
#
# 1. PROVISION:
#    terraform plan -var-file=terraform-versioning-demo.tfvars
#    terraform apply -var-file=terraform-versioning-demo.tfvars
#
# 2. DEPLOY VERSION 1:
#    git push origin main
#    (Automatically triggers deploy workflow)
#
# 3. DEPLOY VERSION 2 (with intentional "bug"):
#    echo "VERSION 2 DEPLOYED" >> bluegreen_site/index.html
#    git add bluegreen_site/index.html
#    git commit -m "Deploy version 2"
#    git push origin main
#
# 4. TEST ROLLBACK:
#    gh workflow run rollback.yml
#    Verify traffic switches back to version 1
#
# 5. RESTORE SPECIFIC VERSION:
#    gh workflow run rollback-and-restore.yml -f version_sha=<commit-sha>
#    Verify original version 1 is restored
#
# 6. CLEANUP:
#    terraform destroy -var-file=terraform-versioning-demo.tfvars
#
# ============================================================================
