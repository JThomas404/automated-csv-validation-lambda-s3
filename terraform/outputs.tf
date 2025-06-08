output "upload_bucket_arn" {
  description = "ARN of the CSV upload bucket"
  value       = aws_s3_bucket.billing_upload.arn
}

output "error_bucket_arn" {
  description = "ARN of the error bucket"
  value       = aws_s3_bucket.billing_error.arn
}

output "lambda_role_arn" {
  description = "ARN of the IAM role used by Lambda"
  value       = aws_iam_role.boto3_lambda_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
