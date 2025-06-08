variable "aws_region" {
  default = "us-east-1"
}

variable "bucket_name_upload" {
  description = "S3 bucket name for uploading CSVs"
  type        = string
  default     = "boto3-billing-x"
}

variable "bucket_name_error" {
  description = "S3 bucket name for invalid/error CSVs"
  type        = string
  default     = "boto3-billing-errors-x"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "boto3-projects"
    Environment = "Dev"
  }
}
