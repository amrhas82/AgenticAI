from typing import List
import os
import json
import numpy as np
import ollama

try:
    import psycopg2  # type: ignore
    _HAVE_PSYCOPG2 = True
except Exception:
    psycopg2 = None  # type: ignore
    _HAVE_PSYCOPG2 = False


class VectorDB:
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")
        self.embed_model = os.getenv("EMBED_MODEL", "nomic-embed-text")
        self.embed_dim = int(os.getenv("EMBED_DIM", "768"))
        self._ollama_host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        self._ollama = ollama.Client(host=self._ollama_host)
        # JSON fallback when Postgres or psycopg2 is unavailable
        self._use_postgres = bool(self.connection_string) and _HAVE_PSYCOPG2
        self._json_path = os.getenv("VECTOR_JSON_PATH", "data/memory/vector_store.json")
        if not self._use_postgres:
            os.makedirs(os.path.dirname(self._json_path), exist_ok=True)

    def store_document(self, chunks: List[str], document_name: str):
        """Store document chunks in vector database"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)  # type: ignore
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
            else:
                # JSON fallback store
                records = self._json_load()
                for chunk in chunks:
                    embedding = self._embed_text(chunk)
                    records.append({
                        "document_name": document_name,
                        "chunk_text": chunk,
                        "embedding": embedding,
                    })
                self._json_save(records)
        except Exception as e:
            print(f"Error storing document: {e}")

    def search_similar(self, query: str, limit: int = 5) -> List[str]:
        """Search for similar text chunks using vector similarity"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)  # type: ignore
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
            else:
                # JSON fallback search with cosine similarity
                records = self._json_load()
                if not records:
                    return []
                query_emb = np.asarray(self._embed_text(query), dtype=np.float32)
                def _cosine(a: np.ndarray, b: np.ndarray) -> float:
                    denom = (np.linalg.norm(a) * np.linalg.norm(b))
                    if denom == 0:
                        return 0.0
                    return float(np.dot(a, b) / denom)
                scored = []
                for rec in records:
                    emb = np.asarray(rec.get("embedding", [0.0] * self.embed_dim), dtype=np.float32)
                    score = _cosine(query_emb, emb)
                    scored.append((score, rec.get("chunk_text", "")))
                scored.sort(key=lambda x: x[0], reverse=True)
                return [text for _, text in scored[:limit]]
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
            print(f"Error generating embedding: {e}. Ensure Ollama is reachable at {self._ollama_host} and the embed model '{self.embed_model}' is installed.")
            return [0.0] * self.embed_dim

    def _to_pgvector(self, vector: List[float]) -> str:
        """Convert Python list to pgvector literal"""
        return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"

    def _json_load(self) -> List[dict]:
        try:
            if os.path.exists(self._json_path):
                with open(self._json_path, "r") as f:
                    return json.load(f)
            return []
        except Exception:
            return []

    def _json_save(self, records: List[dict]) -> None:
        try:
            with open(self._json_path, "w") as f:
                json.dump(records, f)
        except Exception as e:
            print(f"Error saving JSON vector store: {e}")