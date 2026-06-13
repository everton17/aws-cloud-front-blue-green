locals {
  buckets = {
    for bucket in var.buckets : bucket.name => bucket
  }

  buckets_website = {
    for k, v in local.buckets : k => v if v.website == true
  }

  production_bucket = {
    for k, v in local.buckets : k => v if v.principal_bucket == true
  }

  rollback_bucket = {
    for k, v in local.buckets : k => v if v.principal_bucket == false && v.website == true
  }

  versioning_buckets = {
    for k, v in local.buckets : k => v if v.principal_bucket == false && v.website == false
  }

  viewer_certificate_arn = var.acm.create ? aws_acm_certificate.this.arn : var.cloudfront.viewer_certificate.acm_certificate_arn
}
