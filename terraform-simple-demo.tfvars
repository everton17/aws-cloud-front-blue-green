# ============================================================================
# DEMO 1: SIMPLE STACK - CloudFront + S3 (No Rollback)
# ============================================================================
# This configuration demonstrates the simplest possible setup:
# - Single S3 bucket (production only)
# - CloudFront distribution
# - No Lambda@Edge, no rollback capability
# - Perfect for: Simple sites, MVPs, quick demos
#
# Estimated cost: ~$0.50-2/month (CloudFront + S3)
# Deploy time: ~5 minutes
# ============================================================================

region = "us-east-1"

# Single production bucket - everything else is commented out
buckets = [
  {
    name                  = "demo-site-production"
    force_destroy         = true              # Auto-delete on terraform destroy
    versioning            = false             # No need to track versions
    website               = false             # Use OAC (private bucket)
    origin_access_control = true              # Recommended security setup
    main_bucket           = true              # This is the production bucket
    index_document        = "index.html"
    error_document        = "index.html"      # Route 404s to index (SPA support)
  }
  # Rollback bucket commented - not needed for simple stack
  # Versions bucket commented - not needed for simple stack
]

cloudfront = {
  enabled             = true
  default_root_object = "index.html"
  aliases = []        # No custom domain (using CloudFront default)

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
    default_ttl            = 3600      # Cache for 1 hour
    max_ttl                = 86400     # Max cache 1 day
  }

  # Optional: Add cache behaviors for specific paths
  ordered_cache_behaviors = [
    {
      path_pattern    = "/api/*"         # API endpoints: no caching
      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      forwarded_values = {
        query_string = true              # Important for APIs!
        cookies = {
          forward = "all"                # Forward cookies to backend
        }
      }
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0         # No caching for API
      max_ttl                = 0
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
      response_code         = 200         # Return 200 for SPA routing
      error_caching_min_ttl = 30
    }
  ]

  viewer_certificate = {
    cloudfront_default_certificate = true  # Use CloudFront's default SSL
  }
}

# Lambda@Edge DISABLED - not needed for simple stack
lambda_edge = {
  enabled = false
}

# Route53 DISABLED - using CloudFront default domain
route53 = {
  enabled = false
}

# ACM DISABLED - using CloudFront default certificate
# When using cloudfront_default_certificate = true, must explicitly set create = false
acm = {
  create = false
}

# GitHub Actions workflow generation
gha_gen_workflows = {
  enabled          = true
  github_org       = "everton17"                        # Your GitHub org
  github_repo      = "aws-cloud-front-blue-green"      # This repo
  role_name        = "github-actions-deploy"           # IAM role name
  workflow_option  = "simple-deploy"                   # Single workflow
  deploy_branch    = "main"                            # Trigger on main push
  build_command    = "cd ./bluegreen_site && npm run build"
  build_output_dir = "./bluegreen_site/dist"
}
