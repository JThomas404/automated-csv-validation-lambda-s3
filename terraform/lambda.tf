resource "aws_lambda_function" "csv_parser" {
  function_name    = "BillingBucketParser"
  filename         = "../BillingBucketParser.zip"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("../BillingBucketParser.zip")

  runtime     = "python3.11"
  role        = aws_iam_role.boto3_lambda_role.arn
  timeout     = 30
  memory_size = 128
  environment {
    variables = {
      BILLING_UPLOAD = "${var.bucket_name_upload}-${random_id.s3_bucket_suffix.hex}"
      BILLING_ERROR  = "${var.bucket_name_error}-${random_id.s3_bucket_suffix.hex}"
    }
  }

  tags = var.tags
}
