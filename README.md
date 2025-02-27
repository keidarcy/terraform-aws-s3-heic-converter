# AWS S3 HEIC to JPEG Converter

This Terraform module sets up an automated HEIC to JPEG image conversion pipeline using AWS S3 and Lambda.

## Features

- Creates two S3 buckets:
  - Source bucket for uploading HEIC images
  - Processed bucket for storing converted JPEG images
- Sets up a Lambda function that automatically converts HEIC images to JPEG format
- Configures S3 event notifications to trigger the Lambda function when new HEIC files are uploaded
- Implements proper IAM roles and permissions
- Automatically builds and deploys the Lambda function

## Prerequisites

- AWS account with appropriate permissions
- Terraform >= 0.13
- Bun.js installed on the machine running Terraform
- zip command-line utility

## Usage

```hcl
module "heic_converter" {
  source  = "keidarcy/s3-heic-converter/aws"

  name = "my-image-converter"

  tags = {
    Environment = "production"
    Project     = "image-processing"
  }
}
```

After applying the Terraform configuration:
1. Upload HEIC images to the source bucket (name available in output `source_bucket_name`)
2. The Lambda function will automatically convert them to JPEG format
3. Find the converted JPEG images in the processed bucket (name available in output `processed_bucket_name`)

## How it Works

1. When you apply this Terraform configuration:
   - Two S3 buckets are created (source and processed)
   - A Lambda function is created with the necessary permissions
   - The Lambda code is automatically built and packaged using Bun.js
   - S3 event notifications are configured to trigger the Lambda function

2. When a HEIC file is uploaded to the source bucket:
   - The Lambda function is triggered
   - It downloads the HEIC file
   - Converts it to JPEG format using the sharp library
   - Uploads the converted JPEG to the processed bucket
   - The original HEIC file remains in the source bucket

## Lambda Function Details

The Lambda function uses:
- Node.js 18.x runtime
- sharp library for image conversion
- AWS SDK v3 for S3 operations
- 512MB memory allocation
- 30-second timeout

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| name | Name prefix for all resources created by this module | string | yes |
| tags | A map of tags to add to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| source_bucket_name | Name of the source S3 bucket where HEIC images will be uploaded |
| source_bucket_arn | ARN of the source S3 bucket |
| processed_bucket_name | Name of the processed S3 bucket where JPEG images will be stored |
| processed_bucket_arn | ARN of the processed S3 bucket |
| lambda_function_name | Name of the Lambda function that converts HEIC to JPEG |
| lambda_function_arn | ARN of the Lambda function |

## License

MIT


