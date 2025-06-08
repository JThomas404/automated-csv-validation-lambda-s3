# Automated CSV Validation and Error Routing with AWS Lambda and S3

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [How It Works](#how-it-works)
- [Tasks and Implementation Steps](#tasks-and-implementation-steps)
- [Local Testing](#local-testing)
- [Lambda Deployment with Environment Variables](#lambda-deployment-with-environment-variables)
- [IAM Role for Lambda S3 Access](#iam-role-for-lambda-s3-access)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered](#errors-encountered)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless data validation pipeline using AWS Lambda and S3, designed to automatically verify the integrity of incoming billing CSV files. When a file is uploaded to an S3 "upload" bucket, the Lambda function is triggered. It validates the content according to predefined business rules (e.g. valid date format, currency type, and product line). If any validation fails, the file is copied to a dedicated error bucket and deleted from the upload location. This approach ensures clean data intake and isolates problematic files for further inspection.

## Real-World Business Value

This solution addresses a real need for finance and data teams that routinely process large volumes of CSV-based billing data. Automating validation reduces human error, ensures only clean data enters the analytics pipeline, and accelerates monthly reporting. By offloading the validation logic to AWS Lambda and S3, the system remains scalable, cost-efficient, and maintenance-free—making it ideal for modern, cloud-native organisations.

---

## Prerequisites

1. A boilerplate Python-based Lambda function named `BillingBucketParser` in a development environment (e.g., VS Code).
2. Two Amazon S3 buckets:
   - `dct-billing-x` for incoming billing CSV files
   - `dct-billing-errors-x` for files that fail validation
3. A collection of sample CSV test files for validation testing.

---

## Project Folder Structure

```

automated-csv-validation-lambda-s3/
├── BillingBucketParser/
│   ├── event.json
│   └── lambda\_function.py
├── BillingBucketParser.zip
├── README.md
├── s3\_files/
│   ├── billing\_data\_bakery\_june\_2025.csv
│   ├── billing\_data\_dairy\_june\_2025.csv
│   └── billing\_data\_meat\_june\_2025.csv
├── terraform/
│   ├── iam.tf
│   ├── lambda.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── s3.tf
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   └── variables.tf
└── venv/

```

---

## How It Works

1. **Trigger**: Uploading a `.csv` file to the primary S3 bucket triggers the Lambda function.
2. **Validation**: The Lambda parses each row and validates:
   - Product line is in a valid set (`Bakery`, `Meat`, `Dairy`)
   - Currency is allowed (`USD`, `MXN`, `CAD`)
   - Dates conform to the format `YYYY-MM-DD`
3. **Routing**:
   - If valid → the file remains
   - If invalid → the file is copied to the error bucket and deleted from the upload bucket

---

## Tasks and Implementation Steps

### 1. Define IAM Role and Permissions

Use Terraform to create an IAM role allowing the Lambda function to:

- Read from the upload bucket
- Write to the error bucket
- Delete invalid files from the source bucket

### 2. Python Lambda Function (`lambda_function.py`)

Key capabilities include:

- Extracting event data from the S3 trigger
- Parsing CSV files using the `csv` module
- Validating fields: product line, currency, and date format
- Copying invalid files to the error bucket and removing them from the upload bucket

```python
error_bucket = os.environ.get('BILLING_ERROR')
obj = s3.Object(billing_bucket, csv_file)
data = obj.get()['Body'].read().decode('utf-8').splitlines()
for row in csv.reader(data[1:], delimiter=','):
    if product_line not in valid_product_lines or currency not in valid_currencies:
        # Copy to error bucket and delete
```

### 3. Terraform Configuration

Define the Lambda function and use environment variables for bucket names:

```hcl
resource "aws_lambda_function" "csv_parser" {
  function_name = "BillingBucketParser"
  ...
  environment {
    variables = {
      BILLING_UPLOAD = "${var.bucket_name_upload}-${random_id.s3_bucket_suffix.hex}"
      BILLING_ERROR  = "${var.bucket_name_error}-${random_id.s3_bucket_suffix.hex}"
    }
  }
}
```

### 4. Configure S3 Trigger

Attach an event notification to the upload bucket (e.g. via Terraform or the AWS Console) to invoke the Lambda on `PUT` events.

---

## Local Testing

### Run Locally

1. Prepare a mock `event.json` file with your bucket name and CSV key.
2. Load the Lambda manually:

```python
import json
from lambda_function import lambda_handler

with open("event.json") as f:
    event = json.load(f)

response = lambda_handler(event, {})
print(response)
```

### Upload Files for Testing

```bash
aws s3 cp s3_files/ s3://<upload-bucket-name>/ --recursive
```

### Example Output

```bash
['1', 'Lone Star Lactose', 'US', 'San Antonio', 'Dairy', 'Artisan Cheese', '2023-05-01', 'USD', '3500.00']
...
{'statusCode': 200, 'body': 'Success!'}
```

---

## Lambda Deployment with Environment Variables

```hcl
resource "aws_lambda_function" "csv_parser" {
  function_name    = "BillingBucketParser"
  filename         = "../BillingBucketParser.zip"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("../BillingBucketParser.zip")
  runtime          = "python3.11"
  role             = aws_iam_role.boto3_lambda_role.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BILLING_UPLOAD = "${var.bucket_name_upload}-${random_id.s3_bucket_suffix.hex}"
      BILLING_ERROR  = "${var.bucket_name_error}-${random_id.s3_bucket_suffix.hex}"
    }
  }

  tags = var.tags
}
```

---

## IAM Role for Lambda S3 Access

```hcl
resource "aws_iam_role" "boto3_lambda_role" {
  name = "lambda-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy_attach" {
  name       = "lambda-s3-policy"
  roles      = [aws_iam_role.boto3_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
```

---

## Design Decisions and Highlights

The validation logic was intentionally encapsulated within the Lambda handler to maintain a single, traceable processing flow. Using environment variables for the bucket names avoided hardcoding and improved portability. Terraform was used to codify infrastructure with reusable and consistent logic, and S3 event triggers provided a serverless, event-driven mechanism to handle real-time uploads.

---

## Errors Encountered

- **CORS Misconfiguration**: Avoided by not using API Gateway.
- **Date Format Errors**: Caught using `datetime.strptime()` wrapped in `try/except`.
- **Terraform Suffix Misalignment**: Resolved with consistent string interpolation and variable referencing.

---

## Skills Demonstrated

- **Boto3 for S3**: Uploading, copying, deleting, and reading file content.
- **Lambda Authoring**: Efficient, clean Python scripting for file validation.
- **Terraform Proficiency**: IAM, Lambda, and bucket provisioning using infrastructure as code.
- **Debugging and Logging**: Clear print statements and exception handling for tracing validation logic.

---

## Conclusion

This project demonstrates the end-to-end design and deployment of a production-grade serverless validation pipeline using AWS services. It showcases expertise in Python, Boto3, Lambda, Terraform, and event-driven design—resulting in a scalable, secure, and automation-friendly system suitable for real-world DevOps and data engineering workflows.

---
