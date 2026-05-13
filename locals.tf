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
}
