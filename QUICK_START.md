# 🚀 Quick Start Guide

## TL;DR - Get Running in 5 Minutes

```bash
# 1. Setup environment
cp .env.example .env

# 2. Start everything (Docker)
docker compose up -d

# 3. Access the app
open http://localhost:8501
```

---

## Prerequisites

### Required
- Docker & Docker Compose
- Ollama running locally

### Optional
- OpenAI API key (for GPT models)
- Klavis MCP running (for MCP features)

---

## Step-by-Step Setup

### 1. Clone & Configure
```bash
# Copy environment template
cp .env.example .env

# Edit configuration (optional)
nano .env
```

### 2. Start Ollama
```bash
# Start Ollama server
ollama serve

# Pull required models
ollama pull llama2
ollama pull nomic-embed-text
```

### 3. Start Application
```bash
# Build and start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f streamlit-app
```

### 4. Access Application
Open browser: **http://localhost:8501**

---

## First Steps in UI

### 1. Upload a Document
1. Click "📚 Documents" in sidebar
2. Upload a PDF, TXT, MD, or DOCX file
3. Wait for processing
4. Document is now searchable

### 2. Chat with Documents
1. Go to "💬 Chat"
2. Select "RAG Assistant" agent
3. Enable "RAG context" toggle
4. Ask questions about your documents

### 3. Try Different Agents
- **General Chat** - General conversation
- **RAG Assistant** - Document Q&A
- **Coder** - Code help with execution
- **Research Assistant** - Multi-source research

### 4. Manage Conversations
1. Click "🗂️ Conversations"
2. Search previous chats
3. Add tags to organize
4. Export conversations

### 5. Configure Settings
1. Click "⚙️ Settings"
2. Configure Ollama host
3. Set embedding model
4. Adjust RAG parameters

---

## Example Scripts

### Memory Management
```bash
python examples/memory_example.py
```
Demo: Save, load, search conversations

### RAG Operations
```bash
python examples/rag_example.py
```
Demo: Upload docs, search, ask questions

### Basic Chat
```bash
python examples/basic_chat.py
```
Demo: Simple CLI chat with Ollama

---

## Common Issues & Fixes

### Issue: Ollama not connecting
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# From Docker, use host.docker.internal
# Already configured in docker-compose.yml
```

### Issue: No models available
```bash
# Pull models first
ollama pull llama2
ollama pull nomic-embed-text

# Refresh browser
```

### Issue: PostgreSQL connection error
No problem! App automatically falls back to JSON storage.

### Issue: MCP not reachable
MCP is optional. Set `MCP_URL` in `.env` if you have Klavis MCP running.

---

## API Keys (Optional)

### OpenAI
```bash
# In .env
OPENAI_API_KEY=sk-...

# Or in UI sidebar
"OPENAI_API_KEY" input field
```

### Other Providers
See `.env.example` for:
- Anthropic (Claude)
- Google Gemini
- Cohere
- Hugging Face

---

## Configuration Quick Reference

### Environment Variables
| Variable | Default | Purpose |
|----------|---------|---------|
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama server URL |
| `EMBED_MODEL` | `nomic-embed-text` | Embedding model |
| `EMBED_DIM` | `768` | Embedding dimensions |
| `MCP_URL` | `http://localhost:8080` | Klavis MCP URL |
| `DATABASE_URL` | `postgresql://...` | PostgreSQL connection |
| `OPENAI_API_KEY` | - | OpenAI API key |

### Docker Ports
- **8501** - Streamlit UI
- **5432** - PostgreSQL
- **11434** - Ollama (host)
- **8080** - MCP (host, optional)

---

## Recommended Models

### Chat Models
```bash
ollama pull llama2        # General purpose
ollama pull mistral       # Fast and capable
ollama pull llama3        # Most advanced
ollama pull phi3:mini     # Lightweight
```

### Coding Models
```bash
ollama pull codellama:7b-instruct
ollama pull deepseek-coder
```

### Embedding Model
```bash
ollama pull nomic-embed-text  # Required for RAG
```

---

## Usage Tips

### Best Practices
1. **Pull models first** before starting the app
2. **Use RAG mode** for document-based questions
3. **Tag conversations** for easy retrieval
4. **Save conversations** before switching contexts
5. **Adjust chunk size** based on document type

### Performance Tips
1. Use PostgreSQL for better vector search
2. Enable reranking for better RAG results
3. Reduce chunk size for faster processing
4. Use smaller models for quick responses
5. Increase embedding dimensions for accuracy

---

## Support & Documentation

- **Full Review**: `REVIEW_SUMMARY.md`
- **Completion Report**: `COMPLETION_REPORT.md`
- **Setup Guide**: `docs/SETUP.md`
- **Architecture**: `docs/HLA.md`
- **README**: `README.md`

---

## Quick Commands Cheatsheet

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart
docker compose restart

# Rebuild
docker compose up -d --build

# Check Ollama
curl http://localhost:11434/api/tags

# Pull model
ollama pull llama2

# List models
ollama list

# Run example
python examples/memory_example.py
```

---

## Health Checks

### Check Application
```bash
curl http://localhost:8501/_stcore/health
```

### Check PostgreSQL
```bash
docker compose exec postgres psql -U ai_user -d ai_playground -c "SELECT version();"
```

### Check Ollama
```bash
curl http://localhost:11434/api/tags
```

### Check MCP (if running)
```bash
curl http://localhost:8080/health
```

---

## Next Steps

1. ✅ Upload your first document
2. ✅ Ask questions with RAG
3. ✅ Try different agents
4. ✅ Experiment with settings
5. ✅ Add API keys for external models
6. ✅ Explore example scripts

---

**Need Help?** Check `REVIEW_SUMMARY.md` for detailed documentation.

**All Set!** 🎉 Your AI Agent Playground is ready to use.
