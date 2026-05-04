
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
  for_each = local.buckets_website

  bucket = aws_s3_bucket.this[each.key].id

  index_document {
    suffix = each.value.index_document
  }

  error_document {
    key = each.value.error_document
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets_website

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


data "aws_iam_policy_document" "allow_public_access_site_buckets" {
  for_each = local.buckets_website

  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this[each.key].arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  for_each = local.buckets_website

  bucket = aws_s3_bucket.this[each.key].id
  policy = data.aws_iam_policy_document.allow_public_access_site_buckets[each.key].json
}
