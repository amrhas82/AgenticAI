-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table for document embeddings
CREATE TABLE IF NOT EXISTS document_embeddings (
    id SERIAL PRIMARY KEY,
    document_name VARCHAR(255),
    chunk_text TEXT,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS embedding_idx ON document_embeddings
USING ivfflat (embedding vector_cosine_ops);