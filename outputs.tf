output "cloudfront_urls" {
  value = join(", ", concat(tolist([aws_cloudfront_distribution.this.domain_name]), tolist(aws_cloudfront_distribution.this.aliases)))
}
