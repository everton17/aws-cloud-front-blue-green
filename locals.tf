locals {
  buckets = {
    for bucket in var.buckets : bucket.name => bucket
  }

  buckets_website = {
    for k, v in local.buckets : k => v if v.website == true
  }
}
