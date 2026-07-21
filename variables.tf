variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for downloads"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "downloads-tsabunkar-hosting"
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}
