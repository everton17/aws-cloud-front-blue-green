resource "aws_acm_certificate" "this" {
  domain_name               = var.acm.wildcard ? "*.${var.route53.domain}" : var.route53.domain
  subject_alternative_names = length(var.cloudfront.aliases) > 0 ? var.cloudfront.aliases : null
  validation_method         = var.acm.validation_method

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}
