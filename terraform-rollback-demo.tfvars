# ============================================================================
# DEMO 2: BLUE-GREEN ROLLBACK STACK - Instant Rollback Capability
# ============================================================================
# This configuration adds instant rollback capability:
# - TWO S3 buckets (production "green" + rollback "blue")
# - Lambda@Edge function to toggle between them
# - SSM Parameter Store for the toggle switch
# - Automatic workflows for deploy and rollback
# - Perfect for: Production sites, zero-downtime deploys
#
# Estimated cost: ~$2-5/month (CloudFront + 2x S3 + Lambda@Edge + SSM)
# Deploy time: ~8 minutes (Lambda@Edge propagation takes ~5 min)
# Demo: Deploy → Test → Rollback → Verify
# ============================================================================

region = "us-east-1"

# TWO buckets: production (main) + rollback (standby)
buckets = [
  {
    name                  = "demo-site-green"          # Current live version
    force_destroy         = true
    versioning            = false
    website               = false
    origin_access_control = true
    main_bucket           = true                        # This is production
    index_document        = "index.html"
    error_document        = "index.html"
  },
  {
    name                  = "demo-site-blue"           # Previous version (standby)
    force_destroy         = true
    versioning            = false
    website               = false
    origin_access_control = true
    main_bucket           = false                       # This is rollback
    index_document        = "index.html"
    error_document        = "index.html"
  }
  # Versions bucket commented - not needed for rollback-only stack
]

cloudfront = {
  enabled             = true
  default_root_object = "index.html"
  aliases = []        # Using CloudFront default domain for demo

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
    default_ttl            = 300       # 5 minutes (faster demo feedback)
    max_ttl                = 3600      # Max 1 hour
  }

  # Example cache behaviors for different content types
  ordered_cache_behaviors = [
    {
      path_pattern    = "/api/*"
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods  = ["GET", "HEAD"]
      forwarded_values = {
        query_string = true
        cookies = {
          forward = "all"
        }
      }
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    },
    {
      path_pattern    = "/static/*"      # Images, CSS, JS
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
      default_ttl            = 31536000  # 1 year (immutable assets)
      max_ttl                = 31536000
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
    cloudfront_default_certificate = true  # Demo with default cert
  }
}

# Lambda@Edge ENABLED - THIS IS THE KEY FEATURE
# Provides instant switching between green (current) and blue (rollback) buckets
lambda_edge = {
  enabled               = true
  cf_access_bucket_mode = "oac"          # Match our private bucket setup
  function_name         = "cloudfront-blue-green-toggle"
  parameter_store_name  = "/BlueGreen/Rollback"
  handler               = "index.handler"
  runtime               = "nodejs20.x"
}

# Route53 DISABLED - using CloudFront default domain for simplicity
route53 = {
  enabled = false
}

# ACM DISABLED - using CloudFront default certificate
# When using cloudfront_default_certificate = true, must explicitly set create = false
acm = {
  create = false
}

# GitHub Actions workflows - generates deploy.yml and rollback.yml
gha_gen_workflows = {
  enabled          = true
  github_org       = "everton17"
  github_repo      = "aws-cloud-front-blue-green"
  role_name        = "github-actions-deploy"
  workflow_option  = "deploy-and-rollback"             # Enables rollback workflow
  deploy_branch    = "main"
  build_command    = "cd ./bluegreen_site && npm run build"
  build_output_dir = "./bluegreen_site/dist"
}
