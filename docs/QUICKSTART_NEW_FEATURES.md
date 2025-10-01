# Quick Start Guide - New Features

This guide helps you quickly start using the newly implemented features.

## 🚀 5-Minute Setup

### 1. Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env and set at minimum:
# DATABASE_URL=postgresql://ai_user:ai_password@postgres:5432/ai_playground
# OLLAMA_HOST=http://host.docker.internal:11434
# EMBED_MODEL=nomic-embed-text
```

### 2. Install Dependencies

```bash
# If running locally (not Docker)
pip install -r requirements.txt

# Or rebuild Docker
docker compose build --no-cache
docker compose up -d
```

### 3. Initialize Database

```bash
# Database will auto-initialize from scripts/init_db.sql
# Verify:
docker exec -it <postgres-container> psql -U ai_user -d ai_playground -c "\dt"

# You should see:
# - document_embeddings (with metadata column)
# - api_keys
```

### 4. Pull Ollama Models

```bash
# Chat model
ollama pull llama3

# Embedding model (required for vector search)
ollama pull nomic-embed-text

# Optional: Code model
ollama pull codellama:7b-instruct
```

## 📚 Feature Quick Tests

### Test 1: Upload a Word Document

1. Open http://localhost:8501
2. Go to **📚 Documents** page
3. Click **Choose file** in sidebar
4. Select a `.docx` file
5. Click **📤 Process & Upload**
6. Should see: "Complete! Uploaded X chunks"

**Success!** Your DOCX file is now in the vector database.

### Test 2: Long-Term Memory

1. Go to **💬 Chat** page
2. Have a conversation (3-4 messages)
3. Click **💾 Save Conversation** in sidebar
4. Add tags if you want (e.g., "test", "demo")
5. Go to **🗂️ Conversations** page
6. You should see your saved conversation

**Try:**
- 🔍 Search for keywords
- 🏷️ Filter by tags
- 💾 Export to Markdown
- 📖 Load back into chat

### Test 3: API Key Management

```python
# In Python console or script
from src.api_key_manager import APIKeyManager

# Create manager
manager = APIKeyManager()

# Generate a key
api_key = manager.create_key(
    name="Test Key",
    description="Testing API keys",
    permissions={"chat": True, "documents": True}
)

print(f"Your API key: {api_key}")
print("⚠️  Save this! You won't see it again.")

# Verify it works
verification = manager.verify_key(api_key)
print(f"Valid: {verification['valid']}")
print(f"Permissions: {verification['permissions']}")

# List all keys
keys = manager.list_keys()
for key in keys:
    print(f"- {key['name']}: Active={key['is_active']}")
```

### Test 4: MCP Integration (Optional)

First, you need a Klavis MCP server running. If you don't have one, skip this test.

```python
from src.mcp_client import MCPClient

mcp = MCPClient("http://localhost:8080")

# Check status
status = mcp.get_status()
print(status)  # Should show "OK" or "Not reachable"

# If reachable, try:
tools = mcp.list_tools()
print(f"Available tools: {[t['name'] for t in tools]}")

resources = mcp.list_resources()
print(f"Available resources: {len(resources)}")
```

### Test 5: Enhanced Vector Search

```python
from src.database.enhanced_vector_db import EnhancedVectorDB

vector_db = EnhancedVectorDB()

# Get stats
stats = vector_db.get_document_stats()
print(f"Documents: {stats['total_documents']}")
print(f"Chunks: {stats['total_chunks']}")

# Search with metadata filter
results = vector_db.search_similar(
    query="machine learning",
    limit=5,
    filters={"file_type": "pdf"},
    rerank=True
)

for i, result in enumerate(results, 1):
    print(f"\n{i}. Score: {result['score']:.3f}")
    print(f"   Text: {result['chunk_text'][:100]}...")
    print(f"   From: {result['metadata'].get('document_name')}")
```

## 🎯 Common Use Cases

### Use Case 1: Research Assistant with Documents

1. **Upload your research papers** (PDF, DOCX)
   - Go to Documents page
   - Upload multiple papers
   - Wait for processing

2. **Ask questions about them**
   - Go to Chat page
   - Select "RAG Assistant" agent
   - Enable "RAG context"
   - Ask: "What are the main findings about X?"

3. **Save insights**
   - Click "Save Conversation"
   - Tag it: "research", "topic-name"
   - Export as Markdown for notes

### Use Case 2: Code Helper with Memory

1. **Select Coder agent**
   - Go to Chat page
   - Choose "Coder (DeepSeek style)"

2. **Ask for code**
   - "Write a Python function to calculate Fibonacci"
   - Agent will write and can execute code

3. **Reference past solutions**
   - Go to Conversations
   - Search: "fibonacci"
   - Load previous conversation
   - Continue from where you left off

### Use Case 3: External Agent Integration

**Scenario:** You want to allow your mobile app to chat via API

```python
# 1. Create an API key (admin/backend)
from src.api_key_manager import APIKeyManager

manager = APIKeyManager()
mobile_key = manager.create_key(
    name="Mobile App",
    description="iOS/Android client",
    permissions={"chat": True, "documents": False},
    expires_days=30
)

# Give this key to your mobile app

# 2. In your mobile app backend, verify requests
@app.route('/chat')
def chat_endpoint():
    api_key = request.headers.get('X-API-Key')
    
    verification = manager.verify_key(api_key)
    if not verification['valid']:
        return {"error": "Unauthorized"}, 401
    
    if not verification['permissions'].get('chat'):
        return {"error": "No chat permission"}, 403
    
    # Process chat...
    return {"response": "..."}

# 3. Revoke when needed
manager.revoke_key("Mobile App")
```

### Use Case 4: Multi-Format Document Analysis

```python
from src.document_processor import DocumentProcessor
from src.database.enhanced_vector_db import EnhancedVectorDB

processor = DocumentProcessor()
vector_db = EnhancedVectorDB()

# Process multiple formats
files = [
    ("report.pdf", "pdf"),
    ("notes.docx", "docx"),
    ("readme.md", "md"),
    ("data.txt", "txt")
]

for filename, file_type in files:
    # Process
    chunks = processor.process_file(filename, file_type)
    
    # Extract metadata
    metadata = processor.extract_metadata(filename)
    metadata['category'] = 'reports'
    
    # Store
    vector_db.store_document(chunks, filename, metadata)
    print(f"✓ Processed {filename}: {len(chunks)} chunks")

# Now search across all
results = vector_db.search_similar(
    "quarterly revenue",
    limit=10,
    filters={"category": "reports"}
)
```

## ⚙️ Configuration Tips

### For Local Development

```env
# .env for local development
DATABASE_URL=postgresql://ai_user:ai_password@localhost:5432/ai_playground
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
ENABLE_API_AUTH=false
```

### For Docker Deployment

```env
# .env for Docker
DATABASE_URL=postgresql://ai_user:ai_password@postgres:5432/ai_playground
OLLAMA_HOST=http://host.docker.internal:11434
EMBED_MODEL=nomic-embed-text
ENABLE_API_AUTH=false
```

### For Production

```env
# .env for production
DATABASE_URL=postgresql://secure_user:strong_password@db_host:5432/ai_prod
OLLAMA_HOST=http://ollama-server:11434
EMBED_MODEL=nomic-embed-text
ENABLE_API_AUTH=true
MASTER_API_KEY=<generate-strong-key>
ENVIRONMENT=production
LOG_LEVEL=WARNING
```

## 🔧 Troubleshooting

### "Module not found: docx"

```bash
pip install python-docx
# or
docker compose build --no-cache
```

### "Table api_keys does not exist"

```bash
# Reinitialize database
docker exec -it <postgres-container> psql -U ai_user -d ai_playground
# Then in psql:
\i /docker-entrypoint-initdb.d/init_db.sql
```

### "MCP not reachable"

This is normal if you don't have a Klavis MCP server running. The app works fine without it.

To set up Klavis MCP:
1. Clone: https://github.com/Klavis-AI/klavis
2. Follow their setup instructions
3. Update `MCP_URL` in your `.env`

### API keys not working

```python
# Check if authentication is enabled
import os
print(os.getenv("ENABLE_API_AUTH"))  # Should be "true"

# Check master key
print(os.getenv("MASTER_API_KEY"))  # Should be set

# Try master key first
from src.api_key_manager import APIKeyManager
manager = APIKeyManager()
result = manager.verify_key(os.getenv("MASTER_API_KEY"))
print(result)  # Should show valid=True
```

## 📖 Learn More

- **Complete docs:** [docs/FEATURES.md](docs/FEATURES.md)
- **Integration guide:** [docs/INTEGRATION.md](docs/INTEGRATION.md)
- **Architecture:** [docs/HLA.md](docs/HLA.md)
- **Review summary:** [REVIEW_SUMMARY.md](REVIEW_SUMMARY.md)

## 🎉 You're Ready!

All features are now set up and ready to use. Enjoy your enhanced AI playground!

**Quick links:**
- Web UI: http://localhost:8501
- Database: localhost:5432
- Ollama: http://localhost:11434

**Need help?** Check the documentation or open an issue on GitHub.
