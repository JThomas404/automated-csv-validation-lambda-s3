# Automated CSV Validation and Error Routing with AWS Lambda and S3

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [Core Implementation Breakdown](#core-implementation-breakdown)
- [Local Testing and Debugging](#local-testing-and-debugging)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Errors Encountered and Resolved](#errors-encountered-and-resolved)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements a serverless data validation pipeline using AWS Lambda and S3, designed to automatically verify the integrity of incoming billing CSV files. The system triggers upon file upload to an S3 bucket, validates content against predefined business rules (date format, currency type, and product line), and routes invalid files to a dedicated error bucket whilst removing them from the primary location. This architecture ensures data quality enforcement and automated error isolation for downstream analytics processes.

## Real-World Business Value

This solution addresses critical data quality challenges faced by finance and operations teams processing high-volume CSV-based billing data. The automated validation pipeline eliminates manual verification overhead, prevents corrupted data from entering analytics workflows, and provides immediate error isolation for remediation. By leveraging serverless architecture, the system delivers cost-effective scalability whilst maintaining zero operational overhead—essential for modern cloud-native organisations requiring reliable data ingestion processes.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0.0 installed locally
- Python 3.11 runtime environment
- Two S3 buckets (created via Terraform):
  - Upload bucket for incoming CSV files
  - Error bucket for validation failures
- Sample CSV test files with billing data structure

## Project Folder Structure

```
automated-csv-validation-lambda-s3-1/
├── BillingBucketParser/
│   ├── event.json                        # Mock S3 event for local testing
│   └── lambda_function.py                # Core validation logic
├── s3_files/                             # Sample CSV test data
│   ├── billing_data_bakery_june_2025.csv
│   ├── billing_data_dairy_june_2025.csv
│   └── billing_data_meat_june_2025.csv
├── terraform/                            # Infrastructure as Code
│   ├── iam.tf                            # IAM roles and policies
│   ├── lambda.tf                         # Lambda function configuration
│   ├── main.tf                           # Provider and version constraints
│   ├── outputs.tf                        # Resource outputs
│   ├── s3.tf                             # S3 bucket definitions
│   └── variables.tf                      # Configurable parameters
└── README.md
```

## Core Implementation Breakdown

### Lambda Function Architecture

The [lambda_function.py](BillingBucketParser/lambda_function.py) implements a robust validation pipeline:

```python
def lambda_handler(event, context):
    s3 = boto3.resource('s3')
    billing_bucket = event['Records'][0]['s3']['bucket']['name']
    csv_file = event['Records'][0]['s3']['object']['key']
    error_bucket = os.environ.get('BILLING_ERROR')

    # Validation logic for product lines, currencies, and date formats
    valid_product_lines = ['Bakery', 'Meat', 'Dairy']
    valid_currencies = ['USD', 'MXN', 'CAD']
```

**Key Features:**

- Environment variable-driven configuration for bucket references
- Comprehensive validation against business rules
- Error handling with file movement and cleanup
- Structured logging for operational visibility

### Terraform Infrastructure

The infrastructure leverages modular Terraform configuration:

- **[main.tf](terraform/main.tf)**: Provider configuration with version constraints
- **[s3.tf](terraform/s3.tf)**: Bucket creation with random suffix generation
- **[lambda.tf](terraform/lambda.tf)**: Function deployment with environment variables
- **[iam.tf](terraform/iam.tf)**: Least privilege security policies

```hcl
resource "aws_lambda_function" "csv_parser" {
  function_name    = "BillingBucketParser"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BILLING_UPLOAD = "${var.bucket_name_upload}-${random_id.s3_bucket_suffix.hex}"
      BILLING_ERROR  = "${var.bucket_name_error}-${random_id.s3_bucket_suffix.hex}"
    }
  }
}
```

## Local Testing and Debugging

### Mock Event Testing

Local validation using [event.json](BillingBucketParser/event.json):

```python
import json
from lambda_function import lambda_handler

with open("event.json") as f:
    event = json.load(f)

response = lambda_handler(event, {})
print(response)
```

### Sample Data Validation

Test files include intentional validation failures:

- **Date Format Error**: `2023/05/11` in dairy CSV (should be `2023-05-11`)
- **Invalid Product Line**: `Candy` in bakery CSV (should be `Bakery`)
- **Invalid Currency**: `ABC` in bakery CSV (should be USD, CAD, or MXN)
- **Negative Values**: `-2500.00` in bakery CSV for testing edge cases

### CLI Testing Commands

```bash
# Deploy infrastructure
cd terraform
terraform init && terraform apply

# Upload test files (replace with actual bucket name)
aws s3 cp ../s3_files/ s3://boto3-billing-x-[suffix]/ --recursive

# Monitor Lambda logs
aws logs tail /aws/lambda/BillingBucketParser --follow
```

## IAM Role and Permissions

The implementation follows least privilege principles with granular S3 permissions:

```hcl
resource "aws_iam_policy" "boto3_lambda_policy" {
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
}
```

**Security Features:**

- Resource-specific ARN restrictions for S3 buckets
- CloudWatch logging permissions for monitoring
- Minimal required permissions for Lambda execution

## Design Decisions and Highlights

### Architectural Choices

**Event-Driven Processing**: S3 event notifications provide immediate processing without polling overhead, ensuring real-time validation and cost efficiency.

**Environment Variable Configuration**: Bucket names are injected via Terraform-managed environment variables, enabling deployment flexibility and avoiding hardcoded dependencies.

**Atomic Error Handling**: Invalid files are copied to error bucket before deletion, ensuring no data loss whilst maintaining clean primary storage.

**Validation Strategy**: Early termination on first error reduces processing overhead whilst comprehensive logging provides debugging visibility.

### Infrastructure Decisions

**Random Bucket Suffixes**: Terraform random_id resource ensures globally unique bucket names across deployments whilst maintaining predictable naming patterns.

**Minimal Lambda Configuration**: 128MB memory and 30-second timeout provide cost-effective resource allocation for CSV processing workloads.

**CloudWatch Integration**: Structured logging with 14-day retention balances operational visibility with cost management.

## Errors Encountered and Resolved

### Date Format Validation

**Issue**: CSV files contained mixed date formats (`YYYY-MM-DD` vs `YYYY/MM/DD`)
**Resolution**: Implemented `datetime.strptime()` with try/except handling to catch `ValueError` exceptions and flag format violations.

### IAM Permission Scope

**Issue**: Initial implementation used overly broad S3 permissions
**Resolution**: Refined IAM policy to resource-specific ARNs with action-level restrictions, implementing true least privilege access.

### Lambda Error Handling

**Issue**: Indentation error in try/except block caused syntax issues
**Resolution**: Corrected indentation in the exception handling block for S3 copy operations, ensuring proper error catching and logging.

### CSV Data Structure

**Issue**: Mixed data formats in test files required robust validation
**Resolution**: Implemented comprehensive validation for product lines, currencies, and date formats with early termination on first error found.

## Skills Demonstrated

### AWS Services Implementation

- **Lambda**: Serverless function development with Python 3.11 runtime
- **S3**: Event-driven architecture with bucket policies and cross-bucket operations
- **IAM**: Least privilege security model with resource-specific permissions
- **CloudWatch**: Logging and monitoring integration for operational visibility

### Infrastructure as Code

- **Terraform**: Modular configuration with provider version constraints
- **Resource Management**: Random ID generation and environment variable injection
- **State Management**: Consistent resource naming and dependency management

### Software Engineering Practices

- **Error Handling**: Comprehensive exception management with graceful degradation
- **Configuration Management**: Environment-driven deployment flexibility
- **Testing Strategy**: Local validation with mock events and sample data
- **Code Quality**: Clean, readable Python with proper separation of concerns

### DevOps and Automation

- **Event-Driven Architecture**: S3 trigger configuration for real-time processing
- **Deployment Automation**: Terraform-managed infrastructure provisioning
- **Monitoring Integration**: CloudWatch logging with retention policies
- **Security Implementation**: Least privilege IAM with audit-ready permissions

## Conclusion

This project demonstrates end-to-end implementation of a production-ready serverless data validation pipeline using modern AWS services and infrastructure as code practices. The solution showcases expertise in event-driven architecture, security-conscious design, and operational excellence through comprehensive monitoring and error handling. The modular Terraform configuration and environment-driven deployment strategy ensure maintainability and scalability for enterprise data processing requirements.

The implementation reflects practical understanding of cloud-native development patterns, cost-effective resource utilisation, and security best practices essential for modern data engineering workflows.
