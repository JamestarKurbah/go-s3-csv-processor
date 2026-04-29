#!/bin/bash
awslocal s3 mb s3://my-csv-bucket
awslocal sqs create-queue --queue-name my-processing-queue

# Optional: Deploy the lambda here if you want it fully automated
# awslocal lambda create-function ... (see Makefile from earlier)