locals {
  buckets = {
    for bucket in var.buckets : bucket.name => bucket
  }
}
