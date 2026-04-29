# Variables
FUNCTION_NAME=s3-csv-processor
BUCKET_NAME=my-csv-bucket
QUEUE_NAME=my-processing-queue
REGION=us-east-1
DB_URL=postgres://localstack:password@postgres:5432/csvdb

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
		--runtime provided.al2 \
		--handler bootstrap \
		--role arn:aws:iam::000000000000:role/lambda-role \
		--zip-file fileb://lambda/function.zip \
		--environment "Variables={DB_URL=$(DB_URL),SQS_URL=http://localstack:4566/000000000000/$(QUEUE_NAME)}"
	@echo "Waiting for Lambda to be active..."
	timeout 5
	@echo "Setting up S3 Trigger..."
	awslocal s3api put-bucket-notification-configuration \
		--bucket $(BUCKET_NAME) \
		--notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"arn:aws:lambda:$(REGION):000000000000:function:$(FUNCTION_NAME)\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

test-upload:
	@echo "Uploading sample CSV..."
	powershell -Command "Set-Content -Path test.csv -Value 'id,name,email,value'; Add-Content -Path test.csv -Value '1,John Doe,john@example.com,100'"
	awslocal s3 cp test.csv s3://$(BUCKET_NAME)/test.csv

clean:
	del /f /q lambda\bootstrap lambda\function.zip test.csv
	-awslocal lambda delete-function --function-name $(FUNCTION_NAME)
	-awslocal s3 rb s3://$(BUCKET_NAME) --force
	-awslocal sqs delete-queue --queue-url http://localhost:4566/000000000000/$(QUEUE_NAME)

reset:
	docker-compose down -v
	docker-compose up -d
	@echo "Waiting for LocalStack..."
	@sleep 10 
	make deploy