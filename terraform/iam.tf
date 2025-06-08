resource "aws_iam_role" "boto3_lambda_role" {
  name = "boto3-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "boto3_lambda_policy" {
  name        = "boto3-lambda-s3-logging-policy"
  description = "Policy allowing Lambda to interact with S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::boto3-billing-x-da014e82"
      },
      {

        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::boto3-billing-errors-x-da014e82"

      }

    ]
  })
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/BillingBucketParser"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_iam_role_policy_attachment" "boto3-lambda-role-attachment" {
  role       = aws_iam_role.boto3_lambda_role.name
  policy_arn = aws_iam_policy.boto3_lambda_policy.arn
}
