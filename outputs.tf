output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.downloads.bucket
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.downloads.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.downloads.id
}
