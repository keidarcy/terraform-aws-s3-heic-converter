output "source_bucket_name" {
  description = "Name of the source S3 bucket where HEIC images will be uploaded"
  value       = aws_s3_bucket.source.id
}

output "source_bucket_arn" {
  description = "ARN of the source S3 bucket"
  value       = aws_s3_bucket.source.arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket where JPEG images will be stored"
  value       = aws_s3_bucket.processed.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function that converts HEIC to JPEG"
  value       = aws_lambda_function.heic_converter.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.heic_converter.arn
}
