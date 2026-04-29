#!/bin/bash

echo "Configuring LocalStack resources..."

# 1. Create S3 Bucket
awslocal s3 mb s3://my-csv-bucket

# 2. Create SQS Queue
awslocal sqs create-queue --queue-name my-processing-queue

# 3. Deploy Lambda 
# We use /var/lib/localstack/ because that's where we mapped our ./lambda folder
awslocal lambda create-function \
    --function-name s3-csv-processor \
    --runtime provided.al2 \
    --handler bootstrap \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --zip-file fileb:///var/lib/localstack/function.zip \
    --environment "Variables={DB_URL=postgres://localstack:password@postgres:5432/csvdb,SQS_URL=http://localstack:4566/000000000000/my-processing-queue}"

# 4. Set up S3 Trigger
awslocal s3api put-bucket-notification-configuration \
    --bucket my-csv-bucket \
    --notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"arn:aws:lambda:us-east-1:000000000000:function:s3-csv-processor\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

echo "Setup complete! Services are ready."