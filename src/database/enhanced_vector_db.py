from typing import List, Dict, Optional, Tuple
import os
import json
import numpy as np
import ollama
from datetime import datetime

# Try psycopg2 first (Python < 3.13), then psycopg (3.13+)
try:
    import psycopg2
    _HAVE_PSYCOPG = True
    _PSYCOPG_VERSION = 2
except Exception:
    try:
        import psycopg as psycopg2  # Use psycopg3 with psycopg2 compatible API
        _HAVE_PSYCOPG = True
        _PSYCOPG_VERSION = 3
    except Exception:
        psycopg2 = None
        _HAVE_PSYCOPG = False
        _PSYCOPG_VERSION = 0


class EnhancedVectorDB:
    """Enhanced vector database with metadata, reranking, and better search"""
    
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")
        self.embed_model = os.getenv("EMBED_MODEL", "nomic-embed-text")
        self.embed_dim = int(os.getenv("EMBED_DIM", "768"))
        self._ollama_host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        self._ollama = ollama.Client(host=self._ollama_host)
        
        self._use_postgres = bool(self.connection_string) and _HAVE_PSYCOPG
        self._json_path = os.getenv("VECTOR_JSON_PATH", "data/memory/vector_store.json")
        
        if not self._use_postgres:
            os.makedirs(os.path.dirname(self._json_path), exist_ok=True)
    
    def store_document(
        self,
        chunks: List[str],
        document_name: str,
        metadata: Optional[Dict] = None
    ):
        """Store document chunks with metadata"""
        if metadata is None:
            metadata = {}
        
        metadata.update({
            "timestamp": datetime.now().isoformat(),
            "document_name": document_name,
            "num_chunks": len(chunks)
        })
        
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                for idx, chunk in enumerate(chunks):
                    embedding = self._embed_text(chunk)
                    chunk_metadata = {**metadata, "chunk_index": idx}
                    
                    cursor.execute(
                        """
                        INSERT INTO document_embeddings 
                        (document_name, chunk_text, embedding, metadata) 
                        VALUES (%s, %s, %s, %s)
                        """,
                        (
                            document_name,
                            chunk,
                            self._to_pgvector(embedding),
                            json.dumps(chunk_metadata)
                        )
                    )
                
                conn.commit()
                cursor.close()
                conn.close()
            else:
                records = self._json_load()
                for idx, chunk in enumerate(chunks):
                    embedding = self._embed_text(chunk)
                    chunk_metadata = {**metadata, "chunk_index": idx}
                    
                    records.append({
                        "document_name": document_name,
                        "chunk_text": chunk,
                        "embedding": embedding,
                        "metadata": chunk_metadata
                    })
                
                self._json_save(records)
                
        except Exception as e:
            print(f"Error storing document: {e}")
    
    def search_similar(
        self,
        query: str,
        limit: int = 5,
        filters: Optional[Dict] = None,
        rerank: bool = True
    ) -> List[Dict[str, any]]:
        """
        Enhanced search with filtering and optional reranking
        
        Returns list of dicts with: chunk_text, score, metadata
        """
        try:
            if self._use_postgres:
                return self._search_postgres(query, limit, filters, rerank)
            else:
                return self._search_json(query, limit, filters, rerank)
        except Exception as e:
            print(f"Error searching documents: {e}")
            return []
    
    def _search_postgres(
        self,
        query: str,
        limit: int,
        filters: Optional[Dict],
        rerank: bool
    ) -> List[Dict]:
        """PostgreSQL vector search with pgvector"""
        conn = psycopg2.connect(self.connection_string)
        cursor = conn.cursor()
        
        query_emb = self._embed_text(query)
        
        # Build query with optional filters
        sql = """
            SELECT chunk_text, embedding <-> %s as distance, metadata
            FROM document_embeddings
        """
        params = [self._to_pgvector(query_emb)]
        
        if filters:
            conditions = []
            for key, value in filters.items():
                conditions.append(f"metadata->>%s = %s")
                params.extend([key, str(value)])
            
            if conditions:
                sql += " WHERE " + " AND ".join(conditions)
        
        sql += " ORDER BY distance LIMIT %s"
        params.append(limit * 2 if rerank else limit)
        
        cursor.execute(sql, params)
        results = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # Convert to dict format
        results_dict = [
            {
                "chunk_text": row[0],
                "score": 1 - float(row[1]),  # Convert distance to similarity
                "metadata": json.loads(row[2]) if row[2] else {}
            }
            for row in results
        ]
        
        if rerank:
            results_dict = self._rerank_results(query, results_dict, limit)
        
        return results_dict[:limit]
    
    def _search_json(
        self,
        query: str,
        limit: int,
        filters: Optional[Dict],
        rerank: bool
    ) -> List[Dict]:
        """JSON-based search with filtering and reranking"""
        records = self._json_load()
        if not records:
            return []
        
        # Apply filters
        if filters:
            filtered_records = []
            for rec in records:
                metadata = rec.get("metadata", {})
                if all(metadata.get(k) == v for k, v in filters.items()):
                    filtered_records.append(rec)
            records = filtered_records
        
        if not records:
            return []
        
        # Calculate similarities
        query_emb = np.asarray(self._embed_text(query), dtype=np.float32)
        
        results = []
        for rec in records:
            emb = np.asarray(
                rec.get("embedding", [0.0] * self.embed_dim),
                dtype=np.float32
            )
            score = self._cosine_similarity(query_emb, emb)
            
            results.append({
                "chunk_text": rec.get("chunk_text", ""),
                "score": score,
                "metadata": rec.get("metadata", {})
            })
        
        # Sort by score
        results.sort(key=lambda x: x["score"], reverse=True)
        
        # Take top results before reranking
        top_results = results[:limit * 2 if rerank else limit]
        
        if rerank:
            top_results = self._rerank_results(query, top_results, limit)
        
        return top_results[:limit]
    
    def _rerank_results(
        self,
        query: str,
        results: List[Dict],
        limit: int
    ) -> List[Dict]:
        """
        Rerank results using keyword matching and context relevance
        This is a simple reranker - for production, consider cross-encoder models
        """
        query_words = set(query.lower().split())
        
        for result in results:
            text = result["chunk_text"].lower()
            text_words = set(text.split())
            
            # Keyword overlap score
            overlap = len(query_words & text_words) / len(query_words) if query_words else 0
            
            # Boost score based on keyword overlap
            result["score"] = result["score"] * 0.7 + overlap * 0.3
        
        # Re-sort by adjusted score
        results.sort(key=lambda x: x["score"], reverse=True)
        
        return results
    
    def get_document_stats(self) -> Dict[str, any]:
        """Get statistics about stored documents"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_chunks,
                        COUNT(DISTINCT document_name) as total_documents
                    FROM document_embeddings
                """)
                
                row = cursor.fetchone()
                cursor.close()
                conn.close()
                
                return {
                    "total_chunks": row[0],
                    "total_documents": row[1]
                }
            else:
                records = self._json_load()
                doc_names = set(rec.get("document_name") for rec in records)
                
                return {
                    "total_chunks": len(records),
                    "total_documents": len(doc_names)
                }
        except Exception as e:
            print(f"Error getting stats: {e}")
            return {"total_chunks": 0, "total_documents": 0}
    
    def delete_document(self, document_name: str) -> bool:
        """Delete all chunks from a specific document"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute(
                    "DELETE FROM document_embeddings WHERE document_name = %s",
                    (document_name,)
                )
                
                conn.commit()
                cursor.close()
                conn.close()
            else:
                records = self._json_load()
                filtered = [
                    rec for rec in records
                    if rec.get("document_name") != document_name
                ]
                self._json_save(filtered)
            
            return True
        except Exception as e:
            print(f"Error deleting document: {e}")
            return False
    
    def list_documents(self) -> List[Dict[str, any]]:
        """List all documents with metadata"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute("""
                    SELECT 
                        document_name,
                        COUNT(*) as chunk_count,
                        MAX(metadata->>'timestamp') as last_updated
                    FROM document_embeddings
                    GROUP BY document_name
                    ORDER BY last_updated DESC
                """)
                
                results = [
                    {
                        "name": row[0],
                        "chunks": row[1],
                        "last_updated": row[2]
                    }
                    for row in cursor.fetchall()
                ]
                
                cursor.close()
                conn.close()
                return results
            else:
                records = self._json_load()
                doc_info = {}
                
                for rec in records:
                    name = rec.get("document_name")
                    if name not in doc_info:
                        doc_info[name] = {
                            "name": name,
                            "chunks": 0,
                            "last_updated": rec.get("metadata", {}).get("timestamp")
                        }
                    doc_info[name]["chunks"] += 1
                
                return sorted(
                    doc_info.values(),
                    key=lambda x: x["last_updated"] or "",
                    reverse=True
                )
        except Exception as e:
            print(f"Error listing documents: {e}")
            return []
    
    def _embed_text(self, text: str) -> List[float]:
        """Create embedding vector using Ollama"""
        try:
            response = self._ollama.embeddings(model=self.embed_model, prompt=text)
            vector = response.get("embedding")
            
            if vector is None:
                raise ValueError("No embedding returned from Ollama")
            
            if len(vector) != self.embed_dim:
                if len(vector) > self.embed_dim:
                    vector = vector[:self.embed_dim]
                else:
                    vector = vector + [0.0] * (self.embed_dim - len(vector))
            
            return vector
        except Exception as e:
            print(f"Error generating embedding: {e}")
            return [0.0] * self.embed_dim
    
    def _cosine_similarity(self, a: np.ndarray, b: np.ndarray) -> float:
        """Calculate cosine similarity between two vectors"""
        denom = (np.linalg.norm(a) * np.linalg.norm(b))
        if denom == 0:
            return 0.0
        return float(np.dot(a, b) / denom)
    
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
