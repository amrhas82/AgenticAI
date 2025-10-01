#!/usr/bin/env python3
"""
RAG (Retrieval Augmented Generation) example
Demonstrates document upload, vector search, and context-aware responses
Run with: python examples/rag_example.py
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from document_processor import DocumentProcessor
from database.enhanced_vector_db import EnhancedVectorDB
from ollama_client import OllamaClient


def main():
    print("=" * 60)
    print("RAG (Retrieval Augmented Generation) Example")
    print("=" * 60)
    
    # Initialize components
    doc_processor = DocumentProcessor()
    vector_db = EnhancedVectorDB()
    ollama = OllamaClient()
    
    # Get available models
    models = ollama.get_available_models()
    if not models:
        print("\n❌ No Ollama models found. Please pull a model first:")
        print("   ollama pull llama2")
        return
    
    model = models[0]
    print(f"\n✅ Using model: {model}")
    
    # Check vector DB status
    stats = vector_db.get_document_stats()
    print(f"\n📊 Vector DB stats:")
    print(f"   Documents: {stats.get('total_documents', 0)}")
    print(f"   Chunks: {stats.get('total_chunks', 0)}")
    
    print("\n" + "=" * 60)
    print("Commands:")
    print("  upload <file_path>  - Upload and process a document")
    print("  list                - List all documents")
    print("  search <query>      - Search documents")
    print("  ask <question>      - Ask question with RAG context")
    print("  delete <doc_name>   - Delete a document")
    print("  quit                - Exit")
    print("=" * 60 + "\n")
    
    while True:
        try:
            user_input = input("Command: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() == 'quit':
                break
            
            # Upload document
            if user_input.lower().startswith('upload '):
                file_path = user_input[7:].strip()
                
                if not os.path.exists(file_path):
                    print(f"❌ File not found: {file_path}\n")
                    continue
                
                print(f"📄 Processing {file_path}...")
                
                # Read and process file
                with open(file_path, 'rb') as f:
                    filename = os.path.basename(file_path)
                    chunks = doc_processor.process_file(f, filename)
                
                if chunks:
                    print(f"✅ Extracted {len(chunks)} chunks")
                    print(f"📦 Storing in vector database...")
                    
                    vector_db.store_document(
                        chunks,
                        filename,
                        metadata={
                            "source": "cli_upload",
                            "file_path": file_path
                        }
                    )
                    
                    print(f"✅ Document stored successfully!\n")
                else:
                    print(f"❌ No content extracted from file\n")
                
                continue
            
            # List documents
            if user_input.lower() == 'list':
                docs = vector_db.list_documents()
                if docs:
                    print("\n📚 Documents in database:")
                    for i, doc in enumerate(docs, 1):
                        name = doc.get('name', 'Unknown')
                        chunks = doc.get('chunks', 0)
                        updated = doc.get('last_updated', '')[:19]
                        print(f"{i}. {name} - {chunks} chunks (updated: {updated})")
                    print()
                else:
                    print("No documents found\n")
                continue
            
            # Search documents
            if user_input.lower().startswith('search '):
                query = user_input[7:].strip()
                
                if not query:
                    print("Please provide a search query\n")
                    continue
                
                print(f"\n🔍 Searching for: '{query}'...\n")
                
                results = vector_db.search_similar(query, limit=5, rerank=True)
                
                if results:
                    print(f"Found {len(results)} relevant chunks:\n")
                    for i, result in enumerate(results, 1):
                        score = result.get('score', 0)
                        text = result.get('chunk_text', '')[:200]
                        meta = result.get('metadata', {})
                        doc_name = meta.get('document_name', 'Unknown')
                        
                        print(f"{i}. [Score: {score:.3f}] from {doc_name}")
                        print(f"   {text}...\n")
                else:
                    print("No results found\n")
                
                continue
            
            # Ask with RAG
            if user_input.lower().startswith('ask '):
                question = user_input[4:].strip()
                
                if not question:
                    print("Please provide a question\n")
                    continue
                
                print(f"\n💭 Finding relevant context for: '{question}'...\n")
                
                # Search for relevant context
                results = vector_db.search_similar(question, limit=3, rerank=True)
                
                if results:
                    # Build context
                    context = "\n\n".join([
                        r.get('chunk_text', '') for r in results
                    ])
                    
                    # Create RAG prompt
                    rag_prompt = f"""Based on the following context, answer the question. If the answer is not in the context, say so.

Context:
{context}

Question: {question}

Answer:"""
                    
                    print("🤖 AI Response:\n")
                    response = ollama.generate_response(rag_prompt, [], model)
                    print(response + "\n")
                    
                    # Show sources
                    print("\n📎 Sources:")
                    for i, result in enumerate(results, 1):
                        meta = result.get('metadata', {})
                        doc_name = meta.get('document_name', 'Unknown')
                        score = result.get('score', 0)
                        print(f"  {i}. {doc_name} (relevance: {score:.2f})")
                    print()
                else:
                    print("❌ No relevant context found. Try uploading relevant documents first.\n")
                    
                    # Ask without context
                    fallback = input("Ask without context? (y/n): ").strip().lower()
                    if fallback == 'y':
                        print("\n🤖 AI Response (without context):\n")
                        response = ollama.generate_response(question, [], model)
                        print(response + "\n")
                
                continue
            
            # Delete document
            if user_input.lower().startswith('delete '):
                doc_name = user_input[7:].strip()
                
                if not doc_name:
                    print("Please provide document name\n")
                    continue
                
                confirm = input(f"⚠️  Delete '{doc_name}'? (y/n): ").strip().lower()
                if confirm == 'y':
                    if vector_db.delete_document(doc_name):
                        print(f"✅ Deleted {doc_name}\n")
                    else:
                        print(f"❌ Failed to delete {doc_name}\n")
                
                continue
            
            print("❌ Unknown command. Type 'quit' to exit.\n")
            
        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}\n")
            import traceback
            traceback.print_exc()
    
    print("\nGoodbye!")


if __name__ == "__main__":
    main()
