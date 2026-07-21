locals {
  origin_id = "${var.project_name}-s3-origin"
}

data "archive_file" "lambda_edge" {
  type        = "zip"
  source_file = "${path.module}/lambda_edge.py"
  output_path = "${path.module}/lambda_edge.zip"
}

resource "aws_iam_role" "lambda_edge" {
  name = "${var.project_name}-lambda-edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_edge_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.downloads.arn]
  }
}

resource "aws_iam_policy" "lambda_edge_s3" {
  name   = "${var.project_name}-lambda-edge-s3"
  policy = data.aws_iam_policy_document.lambda_edge_s3.json
}

resource "aws_iam_role_policy_attachment" "lambda_edge_s3" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = aws_iam_policy.lambda_edge_s3.arn
}

resource "aws_lambda_function" "directory_listing" {
  filename         = data.archive_file.lambda_edge.output_path
  function_name    = "${var.project_name}-dir-listing"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "lambda_edge.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_edge.output_base64sha256
  publish          = true
}

resource "aws_s3_bucket" "downloads" {
  bucket = var.bucket_name

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "downloads" {
  bucket = aws_s3_bucket.downloads.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

resource "aws_cloudfront_origin_access_control" "downloads" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${var.project_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "downloads" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class

  origin {
    domain_name              = aws_s3_bucket.downloads.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.downloads.id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.directory_listing.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "downloads" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.downloads.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.downloads.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "downloads" {
  bucket = aws_s3_bucket.downloads.id
  policy = data.aws_iam_policy_document.downloads.json
}
