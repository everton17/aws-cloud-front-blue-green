variable "region" {
  type = string
}

variable "buckets" {
  type = list(object({
    name           = string
    force_destroy  = bool
    versioning     = bool
    website        = bool
    index_document = optional(string, "index.html")
    error_document = optional(string, "error.html")
  }))
}

variable "cloudfront" {
  type = object({
    enabled             = bool
    default_root_object = string

    default_cache_behavior = object({
      allowed_methods = list(string)
      cached_methods  = list(string)
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
      path_pattern    = string
      allowed_methods = list(string)
      cached_methods  = list(string)
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

    viewer_certificate = object({
      cloudfront_default_certificate = optional(bool, true)
      acm_certificate_arn            = optional(string)
      ssl_support_method             = optional(string, "sni-only")
    })

    tags = optional(map(string))
  })
}

