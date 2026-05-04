resource "aws_cloudfront_distribution" "this" {


  dynamic "origin" {
    for_each = local.buckets_website
    content {
      domain_name = aws_s3_bucket.this[origin.key].bucket_regional_domain_name
      origin_id   = "${origin.value.name}-origin"
    }
  }

  enabled             = var.cloudfront.enabled
  default_root_object = var.cloudfront.default_root_object

  default_cache_behavior {
    allowed_methods  = var.cloudfront.default_cache_behavior.allowed_methods
    cached_methods   = var.cloudfront.default_cache_behavior.cached_methods
    target_origin_id = "${local.buckets_website["site-production"].name}-origin"

    forwarded_values {
      query_string = var.cloudfront.default_cache_behavior.forwarded_values.query_string

      cookies {
        forward = var.cloudfront.default_cache_behavior.forwarded_values.cookies.forward
      }
    }

    viewer_protocol_policy = var.cloudfront.default_cache_behavior.viewer_protocol_policy
    min_ttl                = var.cloudfront.default_cache_behavior.min_ttl
    default_ttl            = var.cloudfront.default_cache_behavior.default_ttl
    max_ttl                = var.cloudfront.default_cache_behavior.max_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront.restrictions.geo_restriction.restriction_type
    }
  }

  tags = var.cloudfront.tags

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn            = var.cloudfront.viewer_certificate.cloudfront_default_certificate ? null : var.cloudfront.viewer_certificate.acm_certificate_arn
    ssl_support_method             = var.cloudfront.viewer_certificate.cloudfront_default_certificate ? null : var.cloudfront.viewer_certificate.ssl_support_method
  }
}
