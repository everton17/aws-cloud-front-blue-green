
resource "random_id" "bucket_suffix" {
  for_each = local.buckets

  byte_length = 2
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = "${each.value.name}-${random_id.bucket_suffix[each.key].hex}"
  force_destroy = each.value.force_destroy


  tags = {
    Name = "${each.value.name}-${random_id.bucket_suffix[each.key].hex}"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = each.value.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_website_configuration" "this" {
  for_each = {
    for k, v in local.buckets : k => v if v.website == true
  }

  bucket = aws_s3_bucket.this[each.key].id

  index_document {
    suffix = each.value.index_document
  }

  error_document {
    key = each.value.error_document
  }
}
