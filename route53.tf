data "aws_route53_zone" "this" {
  name         = var.route53.domain
  private_zone = var.route53.private_zone
}

resource "aws_route53_record" "this" {
  count   = var.route53.enabled && length(var.cloudfront.aliases) > 0 ? length(var.cloudfront.aliases) : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.cloudfront.aliases[count.index]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = true
  }
}
