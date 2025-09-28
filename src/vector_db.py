import psycopg2
import numpy as np
from typing import List
import os


class VectorDB:
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")

    def store_document(self, chunks: List[str], document_name: str):
        """Store document chunks in vector database"""
        try:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()

            for chunk in chunks:
                # For now, store without embeddings (we'll add embedding generation later)
                cursor.execute(
                    "INSERT INTO document_embeddings (document_name, chunk_text) VALUES (%s, %s)",
                    (document_name, chunk)
                )

            conn.commit()
            cursor.close()
            conn.close()

        except Exception as e:
            print(f"Error storing document: {e}")

    def search_similar(self, query: str, limit: int = 5) -> List[str]:
        """Search for similar text chunks (placeholder for now)"""
        try:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()

            cursor.execute(
                "SELECT chunk_text FROM document_embeddings LIMIT %s",
                (limit,)
            )

            results = [row[0] for row in cursor.fetchall()]

            cursor.close()
            conn.close()

            return results

        except Exception as e:
            print(f"Error searching documents: {e}")
            return []