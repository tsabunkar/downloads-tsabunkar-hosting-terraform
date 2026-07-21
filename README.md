# downloads-tsabunkar-hosting-terraform

Terraform configuration for hosting downloads.tsabunkar.com.

Creates an S3 bucket with a CloudFront distribution, SSE-S3 encryption, OAC (Origin Access Control), and a bucket policy restricting access to CloudFront only.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Outputs

| Name | Description |
|------|-------------|
| `s3_bucket_name` | S3 bucket name |
| `cloudfront_domain_name` | CloudFront distribution domain name |
| `cloudfront_distribution_id` | CloudFront distribution ID |
