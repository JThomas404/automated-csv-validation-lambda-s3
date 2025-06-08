import csv
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    # Initialise the S3 resource using boto3
    s3 = boto3.resource('s3')

    # Extract the bucket name and the CSV file name form the 'event' input
    billing_bucket = event['Records'][0]['s3']['bucket']['name']
    csv_file = event ['Records'][0]['s3']['object']['key']

    # Define the name of the error bucket to copy the erroneous CSV files
    # Referencing the environment variables created for the S3 buckets in lambda.tf
    error_bucket = os.environ.get('BILLING_ERROR')

    # Download the CSV file from S3, read the content, decode from bytes to string, and split the content by lines.
    obj = s3.Object(billing_bucket, csv_file)
    data = obj.get()['Body'].read().decode('utf-8').splitlines()

    # Initialise a flag (error_found) to false. This flag will be set to true when an error is found.
    error_found = False 

    # Define valid product lines and valid currencies.
    valid_product_lines = ['Bakery', 'Meat', 'Dairy']
    valid_currencies = ['USD', 'Rands', 'Bitcoin']



    # Read the CSV content line by line using the Python's csv reader. Ignore the header line (data[1:])
    for row in csv.reader(data[1:], delimiter = ','):
        print(f"{row}")


    return {
        'statusCode': 200,
        'body': "Success!"
    }


