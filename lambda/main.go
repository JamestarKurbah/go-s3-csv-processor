package main

import (
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/sync/errgroup"
)

type Record struct {
	ID    string
	Name  string
	Email string
	Value string
}

const WorkerCount = 50

func handler(ctx context.Context, s3Event events.S3Event) error {
	// 1. Init AWS clients
	cfg, _ := config.LoadDefaultConfig(ctx)
	s3Client := s3.NewFromConfig(cfg)
	sqsClient := sqs.NewFromConfig(cfg)

	// 2. Init DB pool
	dbpool, err := pgxpool.New(ctx, os.Getenv("DB_URL"))
	if err != nil {
		return fmt.Errorf("db connect: %w", err)
	}
	defer dbpool.Close()

	for _, record := range s3Event.Records {
		bucket := record.S3.Bucket.Name
		key := record.S3.Object.Key
		log.Printf("Processing s3://%s/%s", bucket, key)

		// 3. Download CSV from S3
		obj, err := s3Client.GetObject(ctx, &s3.GetObjectInput{
			Bucket: &bucket,
			Key:    &key,
		})
		if err != nil {
			return err
		}

		// 4. Parse CSV + process with worker pool
		reader := csv.NewReader(obj.Body)
		records, _ := reader.ReadAll()

		jobs := make(chan Record, len(records))
		g, ctx := errgroup.WithContext(ctx)

		// Start workers
		for w := 0; w < WorkerCount; w++ {
			g.Go(func() error {
				for rec := range jobs {
					// Insert to PostgreSQL
					_, err := dbpool.Exec(ctx,
						"INSERT INTO processed_records (id, name, email, value, processed_at) VALUES ($1,$2,$3,$4,$5)",
						rec.ID, rec.Name, rec.Email, rec.Value, time.Now())
					if err != nil {
						return err
					}
				}
				return nil
			})
		}

		// Send jobs
		for i, row := range records {
			if i == 0 {
				continue
			} // skip header
			jobs <- Record{ID: row[0], Name: row[1], Email: row[2], Value: row[3]}
		}
		close(jobs)

		if err := g.Wait(); err != nil {
			return err
		}

		// 5. Send SQS notification
		sqsClient.SendMessage(ctx, &sqs.SendMessageInput{
			QueueUrl:    aws.String(os.Getenv("SQS_URL")),
			MessageBody: aws.String(fmt.Sprintf("Processed %d records from %s", len(records)-1, key)),
		})

		log.Printf("Completed: %d records", len(records)-1)
	}
	return nil
}

func main() {
	lambda.Start(handler)
}
