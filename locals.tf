locals {
  buckets = {
    for bucket in var.buckets : bucket.name => bucket
  }

  buckets_website = {
    for k, v in local.buckets : k => v if v.website == true && v.versions_bucket == false
  }

  buckets_oac = {
    for k, v in local.buckets : k => v if v.origin_access_control == true && v.versions_bucket == false
  }

  production_bucket = {
    for k, v in local.buckets : k => v if v.principal_bucket == true && v.versions_bucket == false
  }

  rollback_bucket = {
    for k, v in local.buckets : k => v if v.principal_bucket == false && v.versions_bucket == false
  }

  versioning_buckets = {
    for k, v in local.buckets : k => v if v.versions_bucket == true
  }

  viewer_certificate_arn = var.acm.create ? aws_acm_certificate.this.arn : var.cloudfront.viewer_certificate.acm_certificate_arn
}
