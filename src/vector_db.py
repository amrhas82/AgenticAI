import psycopg2
import numpy as np
from typing import List, Optional, Tuple
import os
import ollama


class VectorDB:
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")
        self.embed_model = os.getenv("EMBED_MODEL", "nomic-embed-text")
        self.embed_dim = int(os.getenv("EMBED_DIM", "768"))
        self._ollama = ollama.Client()

    def store_document(self, chunks: List[str], document_name: str):
        """Store document chunks in vector database"""
        try:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()

            for chunk in chunks:
                embedding = self._embed_text(chunk)
                cursor.execute(
                    "INSERT INTO document_embeddings (document_name, chunk_text, embedding) VALUES (%s, %s, %s)",
                    (document_name, chunk, self._to_pgvector(embedding))
                )

            conn.commit()
            cursor.close()
            conn.close()

        except Exception as e:
            print(f"Error storing document: {e}")

    def search_similar(self, query: str, limit: int = 5) -> List[str]:
        """Search for similar text chunks using vector similarity"""
        try:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()

            query_emb = self._embed_text(query)
            cursor.execute(
                """
                SELECT chunk_text
                FROM document_embeddings
                ORDER BY embedding <-> %s
                LIMIT %s
                """,
                (self._to_pgvector(query_emb), limit)
            )

            results = [row[0] for row in cursor.fetchall()]

            cursor.close()
            conn.close()

            return results

        except Exception as e:
            print(f"Error searching documents: {e}")
            return []

    def _embed_text(self, text: str) -> List[float]:
        """Create embedding vector using Ollama embeddings API"""
        try:
            response = self._ollama.embeddings(model=self.embed_model, prompt=text)
            vector = response.get("embedding")
            if vector is None:
                raise ValueError("No embedding returned from Ollama")
            if len(vector) != self.embed_dim:
                # Attempt to trim or pad to match configured dim
                if len(vector) > self.embed_dim:
                    vector = vector[: self.embed_dim]
                else:
                    vector = vector + [0.0] * (self.embed_dim - len(vector))
            return vector
        except Exception as e:
            print(f"Error generating embedding: {e}")
            return [0.0] * self.embed_dim

    def _to_pgvector(self, vector: List[float]) -> str:
        """Convert Python list to pgvector literal"""
        return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"