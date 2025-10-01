# AI Agent Playground - Complete Feature Documentation

## Table of Contents
1. [Overview](#overview)
2. [Core Features](#core-features)
3. [Installation & Setup](#installation--setup)
4. [Configuration](#configuration)
5. [Feature Deep Dive](#feature-deep-dive)
6. [API Reference](#api-reference)
7. [Troubleshooting](#troubleshooting)

---

## Overview

AI Agent Playground is a comprehensive local AI development platform that enables:
- 🤖 **Multi-Agent System** with specialized agents for different tasks
- 💾 **Persistent Memory** using JSON-based conversation storage
- 📚 **RAG (Retrieval Augmented Generation)** with vector database support
- 🔌 **MCP Integration** for Klavis AI self-hosted tools
- 🦙 **Local LLMs** via Ollama (no API keys required)
- 🌐 **External LLMs** via OpenAI API
- 🔐 **API Key Management** for external agent access
- 📄 **Document Processing** (PDF, TXT, MD, DOCX)

---

## Core Features

### ✅ 1. MCP Self-Hosted from Klavis MCP

**Status:** ✅ Fully Implemented

The system includes a comprehensive MCP (Model Context Protocol) client that integrates with Klavis AI's open-source MCP server.

**Features:**
- List and execute tools from MCP server
- Access resources (files, databases)
- Execute prompt templates
- Send notifications
- Full authentication support

**Configuration:**
```env
MCP_URL=http://localhost:8080
MCP_API_KEY=your_api_key_here  # Optional
```

**Usage Example:**
```python
from mcp_client import MCPClient

mcp = MCPClient()
status = mcp.get_status()
tools = mcp.list_tools()
result = mcp.call_tool("tool_name", {"param": "value"})
```

**Reference:** https://github.com/Klavis-AI/klavis

---

### ✅ 2. Longer Memory Through Simple JSON

**Status:** ✅ Fully Implemented

Enhanced conversation memory system with tagging, search, and export capabilities.

**Features:**
- Automatic conversation saving
- Tag-based organization
- Full-text search across conversations
- Export to JSON, Markdown, or TXT
- Conversation branching and history
- Quick access to recent conversations

**Storage Location:**
- `data/memory/conversations.json` - Main conversation storage
- Keeps last 100 conversations by default

**Usage:**
```python
from ui.conversation_manager import EnhancedMemoryManager

memory = EnhancedMemoryManager()
conv_id = memory.save_conversation(messages, title="My Chat", tags=["python"])
conversations = memory.load_conversations(tags=["python"], limit=10)
results = memory.search_conversations("vector database")
```

---

### ✅ 3. Upload Text, Docs, PDF - Store in Vector DB

**Status:** ✅ Fully Implemented

Comprehensive document processing with vector storage for semantic search.

**Supported Formats:**
- ✅ PDF (.pdf) - via PyPDF2
- ✅ Text (.txt, .md) - native
- ✅ Word Documents (.docx) - via python-docx

**Features:**
- Chunking with configurable size and overlap
- Metadata extraction
- PostgreSQL + pgvector for production
- JSON fallback for development
- Semantic search with reranking
- Document management UI

**Configuration:**
```env
DATABASE_URL=postgresql://ai_user:ai_password@postgres:5432/ai_playground
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
VECTOR_JSON_PATH=data/memory/vector_store.json  # Fallback
```

**Usage:**
```python
from document_processor import DocumentProcessor
from database.enhanced_vector_db import EnhancedVectorDB

processor = DocumentProcessor(chunk_size=1000, chunk_overlap=200)
vector_db = EnhancedVectorDB()

# Process and store
chunks = processor.process_file(uploaded_file, file_type="pdf")
vector_db.store_document(chunks, "document_name.pdf", metadata={})

# Search
results = vector_db.search_similar("query", limit=5, rerank=True)
```

---

### ✅ 4. Local LLMs Through Ollama

**Status:** ✅ Fully Implemented

Full integration with Ollama for running LLMs locally without internet or API keys.

**Supported Operations:**
- Chat completions
- Embeddings generation
- Model listing
- Dynamic model selection
- Context-aware conversations

**Configuration:**
```env
OLLAMA_HOST=http://localhost:11434
```

**Docker Support:**
```yaml
# docker-compose.yml
environment:
  - OLLAMA_HOST=http://host.docker.internal:11434
extra_hosts:
  - "host.docker.internal:host-gateway"
```

**Recommended Models:**
```bash
# Chat models
ollama pull llama3
ollama pull mistral
ollama pull qwen2.5:7b

# Code models
ollama pull codellama:7b-instruct

# Embeddings
ollama pull nomic-embed-text
```

**Usage:**
```python
from ollama_client import OllamaClient

ollama = OllamaClient()
models = ollama.get_available_models()
response = ollama.generate_response(prompt, history, model="llama3")
```

---

### ✅ 5. API Keys for External Agents

**Status:** ✅ Fully Implemented

Secure API key management system for external agent authentication.

**Features:**
- API key generation with secure hashing
- Permission-based access control
- Key expiration support
- Usage tracking (last used timestamp)
- Key revocation
- PostgreSQL or JSON storage

**Database Schema:**
```sql
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    key_hash VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(255),
    description TEXT,
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    expires_at TIMESTAMP
);
```

**Configuration:**
```env
ENABLE_API_AUTH=true
MASTER_API_KEY=your_master_key_here
```

**Usage:**
```python
from api_key_manager import APIKeyManager

manager = APIKeyManager()

# Create key
api_key = manager.create_key(
    name="External Agent",
    description="For my automation",
    permissions={"chat": True, "documents": True},
    expires_days=30
)

# Verify key
verification = manager.verify_key(api_key)
if verification["valid"]:
    print(f"Authenticated: {verification['name']}")
```

**Decorator for Protection:**
```python
from api_key_manager import require_api_key

@require_api_key("documents")
def upload_document():
    # Protected function
    pass
```

---

## Installation & Setup

### Quick Start (Linux/Ubuntu)

```bash
chmod +x setup.sh && ./setup.sh
```

### Windows (WSL2 + Docker Desktop)

```bash
chmod +x setup-win.sh && ./setup-win.sh
```

### Manual Setup

1. **Install Ollama:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull llama3
ollama pull nomic-embed-text
```

2. **Start Services:**
```bash
docker compose up -d
```

3. **Configure Environment:**
```bash
cp .env.example .env
# Edit .env with your settings
```

4. **Access:**
- Web UI: http://localhost:8501
- PostgreSQL: localhost:5432

---

## Configuration

### Environment Variables

See `.env.example` for complete configuration options.

**Key Settings:**

```env
# Database
DATABASE_URL=postgresql://ai_user:ai_password@localhost:5432/ai_playground

# Ollama
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768

# MCP (Klavis AI)
MCP_URL=http://localhost:8080
MCP_API_KEY=optional_key

# Security
ENABLE_API_AUTH=false
MASTER_API_KEY=

# OpenAI (Optional)
OPENAI_API_KEY=
```

### Application Settings

Settings UI available at: `⚙️ Settings` page in the app

- **System:** Ollama host, database, MCP configuration
- **Models:** Per-model temperature, max tokens, etc.
- **RAG:** Chunk size, overlap, similarity threshold
- **Import/Export:** Backup and restore settings

---

## Feature Deep Dive

### Agent System

**Available Agents:**

1. **General Chat**
   - Friendly conversational AI
   - General purpose assistance
   - Temperature: 0.7

2. **RAG Assistant**
   - Document-focused research
   - Vector database search
   - Conversation memory access
   - Temperature: 0.5

3. **Coder (DeepSeek style)**
   - Code generation and debugging
   - Python code execution sandbox
   - Test suggestion
   - Temperature: 0.3

4. **Research Assistant**
   - Multi-document synthesis
   - Source citation
   - Structured findings
   - Temperature: 0.4

**Agent Tools:**

- `search_documents`: Vector search in uploaded docs
- `execute_code`: Safe Python code execution
- `recall_conversation`: Access conversation history

### Vector Database

**Architecture:**
- Primary: PostgreSQL + pgvector extension
- Fallback: JSON file storage
- Embeddings: Ollama (nomic-embed-text)

**Search Features:**
- Cosine similarity
- Metadata filtering
- Result reranking
- Configurable result limits

**Document Stats:**
```python
stats = vector_db.get_document_stats()
# Returns: {total_chunks, total_documents}

documents = vector_db.list_documents()
# Returns: [{name, chunks, last_updated}, ...]
```

### Memory System

**Conversation Structure:**
```json
{
  "id": "abc123",
  "timestamp": "2025-10-01T12:00:00",
  "title": "Discussion about AI",
  "tags": ["ai", "python"],
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "metadata": {},
  "message_count": 10
}
```

**Search Capabilities:**
- Title search
- Content search
- Tag filtering
- Timestamp sorting

### MCP Integration

**Klavis MCP Endpoints:**

- `GET /health` - Server status
- `GET /api/tools` - List available tools
- `POST /api/tools/execute` - Execute a tool
- `GET /api/resources` - List resources
- `GET /api/resources/read` - Read resource content
- `GET /api/prompts` - List prompt templates
- `POST /api/prompts/execute` - Execute prompt
- `POST /api/notifications` - Send notification
- `GET /api/info` - Server information

**Authentication:**
```python
# Bearer token authentication
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}
```

---

## API Reference

### Ollama Client

```python
class OllamaClient:
    def __init__(self)
    def get_available_models(self) -> List[str]
    def generate_response(
        self,
        prompt: str,
        history: List[Dict],
        model: str
    ) -> str
```

### Vector Database

```python
class EnhancedVectorDB:
    def __init__(self)
    def store_document(
        self,
        chunks: List[str],
        document_name: str,
        metadata: Optional[Dict] = None
    )
    def search_similar(
        self,
        query: str,
        limit: int = 5,
        filters: Optional[Dict] = None,
        rerank: bool = True
    ) -> List[Dict]
    def get_document_stats(self) -> Dict
    def list_documents(self) -> List[Dict]
    def delete_document(self, document_name: str) -> bool
```

### Memory Manager

```python
class EnhancedMemoryManager:
    def __init__(self, memory_file: str = "data/memory/conversations.json")
    def save_conversation(
        self,
        messages: List[Dict],
        title: Optional[str] = None,
        tags: Optional[List[str]] = None
    ) -> str
    def load_conversations(
        self,
        tags: Optional[List[str]] = None,
        limit: Optional[int] = None
    ) -> List[Dict]
    def search_conversations(self, query: str) -> List[Dict]
    def export_conversation(
        self,
        conversation_id: str,
        format: str = "json"
    ) -> Optional[str]
```

### API Key Manager

```python
class APIKeyManager:
    def __init__(self)
    def create_key(
        self,
        name: str,
        description: str = "",
        permissions: Optional[Dict] = None,
        expires_days: Optional[int] = None
    ) -> Optional[str]
    def verify_key(self, api_key: str) -> Dict[str, any]
    def list_keys(self) -> List[Dict]
    def revoke_key(self, name: str) -> bool
```

### MCP Client

```python
class MCPClient:
    def __init__(self, mcp_url: str | None = None)
    def list_tools(self) -> List[Dict[str, Any]]
    def call_tool(
        self,
        tool_name: str,
        parameters: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]
    def list_resources(self) -> List[Dict[str, Any]]
    def read_resource(self, resource_uri: str) -> Dict[str, Any]
    def get_prompts(self) -> List[Dict[str, Any]]
    def execute_prompt(
        self,
        prompt_name: str,
        arguments: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]
```

---

## Troubleshooting

### Ollama Connection Issues

**Problem:** "Connection refused" errors

**Solutions:**
1. Check Ollama is running: `ollama list`
2. Set correct host: `export OLLAMA_HOST=http://localhost:11434`
3. For Docker: Use `http://host.docker.internal:11434`
4. Bind to all interfaces: `OLLAMA_HOST=0.0.0.0:11434 ollama serve`

### Database Issues

**Problem:** pgvector extension not found

**Solution:**
```sql
-- Connect to database
psql -h localhost -U ai_user -d ai_playground

-- Enable extension
CREATE EXTENSION IF NOT EXISTS vector;
```

**Problem:** Permission denied

**Solution:**
```bash
# Reinitialize database
docker compose down -v
docker compose up -d
```

### Document Upload Issues

**Problem:** DOCX files not processing

**Solution:**
```bash
pip install python-docx
# Or rebuild container
docker compose build --no-cache
```

**Problem:** Embedding generation fails

**Solution:**
```bash
# Install embedding model
ollama pull nomic-embed-text

# Verify
ollama list | grep nomic
```

### MCP Connection Issues

**Problem:** MCP not reachable

**Solution:**
1. Check MCP server is running
2. Verify URL: `curl http://localhost:8080/health`
3. Check firewall settings
4. Set `MCP_URL` correctly in `.env`

### API Key Issues

**Problem:** Authentication fails

**Solution:**
1. Check `ENABLE_API_AUTH` setting
2. Verify API key format: `sk_...`
3. Check key hasn't expired
4. Verify permissions in database

---

## Performance Tips

1. **Use PostgreSQL for production**
   - Much faster than JSON fallback
   - Better for >1000 chunks

2. **Optimize chunk size**
   - Smaller chunks (500-1000 words) for precise search
   - Larger chunks (1500-2000 words) for context

3. **Enable reranking**
   - Improves result quality
   - Minimal performance cost

4. **Model selection**
   - Use smaller models for faster responses
   - phi3:mini is very fast for simple tasks
   - llama3 for balanced performance

5. **Batch operations**
   - Upload multiple documents at once
   - Use conversation export for backups

---

## Security Best Practices

1. **API Keys**
   - Store master key securely
   - Rotate keys regularly
   - Use expiration dates
   - Revoke unused keys

2. **Database**
   - Change default passwords
   - Use SSL connections in production
   - Regular backups

3. **Network**
   - Use firewall rules
   - Restrict access to internal network
   - Use reverse proxy for external access

4. **Code Execution**
   - Sandbox is basic - don't expose to untrusted users
   - Disable if not needed: `ENABLE_CODE_EXECUTION=false`

---

## Contributing

See main README.md for contribution guidelines.

## License

See LICENSE file in repository.

## Support

- GitHub Issues: https://github.com/your-repo/issues
- Documentation: `/docs/` folder
- Klavis MCP: https://github.com/Klavis-AI/klavis
