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
    target_origin_id = var.cloudfront.default_cache_behavior.target_origin_id != null ? var.cloudfront.default_cache_behavior.target_origin_id : "${local.buckets_website["site-production"].name}-origin"

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

  dynamic "ordered_cache_behavior" {
    for_each = var.cloudfront.ordered_cache_behaviors
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ordered_cache_behavior.value.allowed_methods
      cached_methods   = ordered_cache_behavior.value.cached_methods
      target_origin_id = ordered_cache_behavior.value.optional_target_origin_id != null ? ordered_cache_behavior.value.optional_target_origin_id : "${local.buckets_website["site-production"].name}-origin"

      forwarded_values {
        query_string = ordered_cache_behavior.value.forwarded_values.query_string

        cookies {
          forward = ordered_cache_behavior.value.forwarded_values.cookies.forward
        }
      }

      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      min_ttl                = ordered_cache_behavior.value.min_ttl
      default_ttl            = ordered_cache_behavior.value.default_ttl
      max_ttl                = ordered_cache_behavior.value.max_ttl
    }
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
