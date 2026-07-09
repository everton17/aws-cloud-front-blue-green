output "cloudfront_urls" {
  value = join(", ", concat(
    [aws_cloudfront_distribution.this.domain_name],
    aws_cloudfront_distribution.this.aliases != null ? tolist(aws_cloudfront_distribution.this.aliases) : []
  ))
}
