resource "aws_cloudfront_distribution" "this" {

  enabled             = var.cloudfront.enabled
  default_root_object = var.cloudfront.default_root_object
  comment             = var.cloudfront.comment
  is_ipv6_enabled     = var.cloudfront.is_ipv6_enabled
  http_version        = var.cloudfront.http_version
  price_class         = var.cloudfront.price_class
  web_acl_id          = var.cloudfront.web_acl_id
  retain_on_delete    = var.cloudfront.retain_on_delete
  wait_for_deployment = var.cloudfront.wait_for_deployment
  aliases             = var.cloudfront.aliases

  dynamic "origin" {
    for_each = local.buckets_website
    content {
      domain_name = aws_s3_bucket_website_configuration.this[origin.key].website_endpoint
      origin_id   = "${origin.value.name}-origin"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

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

    # Lambda@Edge association to Origin Request
    dynamic "lambda_function_association" {
      for_each = var.lambda_edge.enabled ? var.lambda_edge.associations : []

      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = aws_lambda_function.edge_rollback[0].qualified_arn
        include_body = lambda_function_association.value.include_body
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

      # Lambda@Edge association to Origin Request
      dynamic "lambda_function_association" {
        for_each = var.lambda_edge.enabled ? var.lambda_edge.associations : []

        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = aws_lambda_function.edge_rollback[0].qualified_arn
          include_body = lambda_function_association.value.include_body
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

  dynamic "custom_error_response" {
    for_each = var.cloudfront.custom_error_response
    content {
      error_code            = custom_error_response.value.error_code
      response_page_path    = custom_error_response.value.response_page_path
      response_code         = custom_error_response.value.response_code
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  dynamic "logging_config" {
    for_each = var.cloudfront.logging_config != null ? [var.cloudfront.logging_config] : []
    content {
      bucket          = aws_s3_bucket.logging[0].bucket_domain_name
      include_cookies = var.cloudfront.logging_config.include_cookies
      prefix          = var.cloudfront.logging_config.prefix
    }
  }

  tags = var.cloudfront.tags

  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront.viewer_certificate.cloudfront_default_certificate
    acm_certificate_arn            = var.cloudfront.viewer_certificate.cloudfront_default_certificate ? null : local.viewer_certificate_arn
    ssl_support_method             = var.cloudfront.viewer_certificate.cloudfront_default_certificate ? null : var.cloudfront.viewer_certificate.ssl_support_method
  }
}
