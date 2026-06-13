variable "region" {
  type = string
}

variable "buckets" {
  type = list(object({
    name             = string
    force_destroy    = bool
    versioning       = bool
    website          = bool
    principal_bucket = bool
    index_document   = optional(string, "index.html")
    error_document   = optional(string, "error.html")
  }))
}

variable "cloudfront" {
  type = object({
    enabled             = bool
    default_root_object = optional(string, null)
    comment             = optional(string, null)
    is_ipv6_enabled     = optional(bool, false)
    http_version        = optional(string, "http2")
    price_class         = optional(string, "PriceClass_All")
    web_acl_id          = optional(string, null)
    retain_on_delete    = optional(bool, false)
    wait_for_deployment = optional(bool, true)
    aliases             = optional(list(string), [])

    logging_config = optional(object({
      bucket          = string
      force_destroy   = optional(bool, false)
      prefix          = optional(string, "")
      include_cookies = optional(bool, false)
    }))

    default_cache_behavior = object({
      allowed_methods  = list(string)
      cached_methods   = list(string)
      target_origin_id = optional(string)
      forwarded_values = object({
        query_string = bool
        cookies = object({
          forward = string
        })
      })
      viewer_protocol_policy = string
      min_ttl                = number
      default_ttl            = number
      max_ttl                = number
    })

    ordered_cache_behaviors = optional(list(object({
      path_pattern              = string
      allowed_methods           = list(string)
      cached_methods            = list(string)
      optional_target_origin_id = optional(string)
      forwarded_values = object({
        query_string = bool
        cookies = object({
          forward = string
        })
      })
      viewer_protocol_policy = string
      min_ttl                = number
      default_ttl            = number
      max_ttl                = number
    })))

    restrictions = object({
      geo_restriction = object({
        restriction_type = string
      })
    })

    custom_error_response = list(object({
      error_code            = number
      response_page_path    = string
      response_code         = number
      error_caching_min_ttl = number
    }))

    viewer_certificate = object({
      cloudfront_default_certificate = optional(bool, true)
      acm_certificate_arn            = optional(string)
      ssl_support_method             = optional(string, "sni-only")
    })

    tags = optional(map(string))
  })
}

variable "lambda_edge" {
  type = object({
    enabled              = optional(bool, true)
    function_name        = optional(string, "cloudfront-rollback-origin-request")
    parameter_store_name = optional(string, "/Lambda/CF/Rollback")
    handler              = optional(string, "index.handler")
    runtime              = optional(string, "nodejs20.x")
    associations = optional(list(object({
      event_type   = string
      include_body = optional(bool, false)
      })), [
      {
        event_type   = "origin-request"
        include_body = false
      }
    ])
  })
}

variable "route53" {
  type = object({
    enabled      = optional(bool, false)
    domain       = optional(string, null)
    private_zone = optional(bool, false)
  })

  validation {
    condition     = !var.route53.enabled || (var.route53.domain != null && trimspace(var.route53.domain) != "")
    error_message = "When 'route53.enabled' is true, the 'route53.domain' field must be set and cannot be empty."
  }
}

variable "acm" {
  type = object({
    create            = optional(bool, true)
    wildcard          = optional(bool, false)
    validation_method = optional(string, "DNS")
  })

  validation {
    condition     = var.cloudfront.viewer_certificate.cloudfront_default_certificate != var.acm.create
    error_message = "'cloudfront.viewer_certificate.cloudfront_default_certificate' and 'acm.create' can't have the same value. If you want to use a custom domain, set 'cloudfront.viewer_certificate.cloudfront_default_certificate' to false."
  }
}
