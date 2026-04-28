# 🚀 AWS Lambda CSV Processor (Go)

## 📌 Overview
A high-performance, serverless data processing pipeline using AWS Lambda in Go.

This service:
- Triggers on S3 uploads
- Processes CSV files concurrently
- Inserts records into PostgreSQL
- Sends completion notifications via SQS

---

## 🏗 Architecture

```
        ┌──────────┐
        │   S3     │
        └────┬─────┘
             │ (event)
             ▼
       ┌────────────┐
       │  Lambda    │
       │ (Worker    │
       │  Pool)     │
       └────┬───────┘
            │
   ┌────────▼────────┐
   │ PostgreSQL (RDS)│
   └────────┬────────┘
            │
            ▼
         ┌─────┐
         │ SQS │
         └─────┘
```

---

## ⚙️ Features

- ⚡ **Concurrent processing** with 50 workers
- 🔌 **Connection pooling** via pgx
- 🧵 **Goroutine orchestration** using errgroup
- ☁️ Fully serverless and scalable
- 📬 Event-driven architecture

---

## 🔧 Environment Variables

| Variable | Description |
|----------|------------|
| `DB_URL` | PostgreSQL connection string |
| `SQS_URL` | Target SQS queue URL |

---

## 📄 CSV Format

Expected CSV structure:

```
id,name,email,value
```

Example:

```
1,John Doe,john@example.com,100
2,Jane Doe,jane@example.com,200
```

---

## 🔄 Processing Flow

1. S3 upload triggers Lambda
2. File is fetched from S3
3. CSV is parsed into records
4. Records are distributed to worker pool
5. Workers insert into PostgreSQL
6. Completion message sent to SQS

---

## 🧵 Worker Pool Design

- Uses buffered channel as job queue
- Fixed worker count (50)
- `errgroup` ensures:
  - Proper cancellation
  - Error propagation
  - Clean shutdown

---

## 🗄 Database Schema

```sql
CREATE TABLE processed_records (
    id TEXT,
    name TEXT,
    email TEXT,
    value TEXT,
    processed_at TIMESTAMP
);
```

---

## 🚀 Deployment

### Build
```
GOOS=linux GOARCH=amd64 go build -o main
```

### Package
```
zip function.zip main
```

### Deploy
Upload `function.zip` to AWS Lambda.

---

## 🔐 IAM Permissions

Ensure Lambda has:

- `s3:GetObject`
- `sqs:SendMessage`
- RDS access (via VPC + security groups)

---

## ⚠️ Limitations

- Loads entire CSV into memory (`ReadAll()`)
- No retry logic for failed inserts
- No batching for DB writes

---

## 🧠 Recommended Improvements

### Performance
- ✅ Batch inserts (COPY or multi-row INSERT)
- ✅ Stream CSV instead of `ReadAll()`
- ✅ Tune worker count dynamically

### Reliability
- 🔁 Add retry + DLQ
- 🧾 Add idempotency handling
- 📊 Add metrics (CloudWatch)

### Observability
- Structured logging (zap/logrus)
- Tracing (AWS X-Ray)
- Monitoring dashboards

---

## 📦 Dependencies

- AWS SDK v2
- AWS Lambda Go SDK
- pgx/v5
- errgroup

---

## 💡 Future Enhancements

- Support multiple file formats (JSON, Parquet)
- Add validation layer
- Introduce schema versioning
- Add API for querying processed data

---

## 🧪 Local Testing

Use AWS SAM or LocalStack:

```
sam local invoke
```

---

## 📜 License
MIT
