CREATE TABLE IF NOT EXISTS processed_records (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    value VARCHAR(100),
    processed_at TIMESTAMP
);