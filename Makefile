# Variables
FUNCTION_NAME=s3-csv-processor
BUCKET_NAME=my-csv-bucket
QUEUE_NAME=my-processing-queue
REGION=us-east-1
# We use 'postgres' as the host because the Lambda runs inside the Docker network
DB_URL=postgres://user:pass@postgres:5432/processor_db 

.PHONY: build deploy clean test-upload

# 1. Build the Go binary for Linux
build:
	@echo "Building Go binary for Linux..."
	cd lambda && set GOOS=linux&& set GOARCH=amd64&& set CGO_ENABLED=0&& go build -o bootstrap main.go
	@echo "Creating zip file..."
	cd lambda && tar -a -c -f function.zip bootstrap

# 2. Setup LocalStack resources
deploy: build
	@echo "Creating SQS Queue..."
	awslocal sqs create-queue --queue-name $(QUEUE_NAME)
	
	@echo "Creating S3 Bucket..."
	awslocal s3 mb s3://$(BUCKET_NAME)

	@echo "Deploying Lambda..."
	awslocal lambda create-function \
		--function-name $(FUNCTION_NAME) \
		--runtime provided.al2023 \
		--handler bootstrap \
		--role arn:aws:iam::000000000000:role/lambda-role \
		--zip-file fileb://lambda/function.zip \
		--environment "Variables={DB_URL=$(DB_URL),SQS_URL=http://sqs.$(REGION).localhost.localstack.cloud:4566/000000000000/$(QUEUE_NAME)}"

	@echo "Setting up S3 Trigger..."
	awslocal s3api put-bucket-notification-configuration \
		--bucket $(BUCKET_NAME) \
		--notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"arn:aws:lambda:$(REGION):000000000000:function:$(FUNCTION_NAME)\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

# 3. Quick test by uploading a file
test-upload:
	@echo "Uploading sample CSV..."
	powershell -Command "Set-Content -Path test.csv -Value 'id,name,email,value'; Add-Content -Path test.csv -Value '1,John Doe,john@example.com,100'"
	awslocal s3 cp test.csv s3://$(BUCKET_NAME)/test.csv

# 4. Clean up
clean:
	del /f /q lambda\bootstrap lambda\function.zip test.csv