# AI Agent System - Quick Reference Card

**Last Updated**: October 1, 2025

---

## 📋 Your Questions - Quick Answers

### Q1: Do all AI agents have different JSON conversation history?

**Answer**: No, currently they share `conversations.json`, but you can filter by agent using tags.

**How to filter**:
```python
# Save with agent tag
memory.save_conversation(messages, tags=["RAG Assistant"])

# Load only RAG Assistant conversations
rag_convs = memory.load_conversations(tags=["RAG Assistant"])
```

**Files**:
- Shared: `data/memory/conversations.json`
- Manager: `src/ui/conversation_manager.py`

---

### Q2: How do I setup MCP Klavis for my AI agent?

**Answer**: Install MCP server, configure URL, and integrate tools.

**Quick Setup**:
```bash
# 1. Start MCP server
docker run -d -p 8080:8080 klavis/mcp-server

# 2. Configure in .env
echo "MCP_URL=http://localhost:8080" >> .env

# 3. Restart app
docker compose restart
```

**Check Status**: Look at sidebar in UI for "MCP Integration" section

**Files**:
- Client: `src/mcp_client.py`
- Integration: See `AGENT_IMPROVEMENTS.md`

---

### Q3: Do AI agents accept docs upload and store on vector DB?

**Answer**: Yes! Upload PDF/TXT/MD/DOCX and they're automatically embedded.

**How to Use**:
1. Go to "Documents" page
2. Upload file
3. Ask RAG Assistant or Research Assistant about it
4. They'll automatically search the vector DB

**Storage**:
- Primary: PostgreSQL + pgvector
- Fallback: `data/memory/vector_store.json`
- Manager: `src/vector_db.py`

---

## 🤖 Available Agents

| Agent | Purpose | Tools | Best For |
|-------|---------|-------|----------|
| **General Chat** | Casual conversation | None | General questions |
| **RAG Assistant** | Document Q&A | SearchTool, MemoryTool | "What does doc X say about Y?" |
| **Coder** | Code generation | CodeExecutorTool | "Write a Python function to..." |
| **Research Assistant** | Multi-source research | SearchTool, MemoryTool | "Research topic X from docs" |
| **MCP Assistant** | External tools | MCPTools (if configured) | Web search, file ops, APIs |

---

## 🛠️ Tools & Capabilities

### SearchTool
- **What**: Searches uploaded documents via vector similarity
- **Used by**: RAG Assistant, Research Assistant
- **Code**: `src/agents/agent_system.py:43`

### MemoryTool
- **What**: Recalls previous conversations
- **Used by**: RAG Assistant, Research Assistant
- **Code**: `src/agents/agent_system.py:121`

### CodeExecutorTool
- **What**: Executes Python code safely
- **Used by**: Coder
- **Code**: `src/agents/agent_system.py:59`

### MCPTool
- **What**: Accesses external MCP services
- **Used by**: MCP Assistant (if configured)
- **Code**: See `AGENT_IMPROVEMENTS.md`

---

## 📁 File Locations

### Configuration
```
.env                              # Environment variables
data/config/system_config.json    # UI settings
```

### Data Storage
```
data/memory/conversations.json    # All conversation history
data/memory/vector_store.json     # Embeddings (JSON mode)
data/documents/                   # Uploaded files
```

### Source Code
```
src/app.py                        # Main app
src/agents/agent_system.py        # Agents & tools
src/vector_db.py                  # Vector storage
src/mcp_client.py                 # MCP integration
src/ui/conversation_manager.py    # Conversation management
src/ui/document_manager.py        # Document upload
```

### Documentation
```
docs/AI_AGENT_GUIDE.md            # ⭐ Complete guide
docs/AGENT_ARCHITECTURE_DIAGRAM.md # Visual diagrams
AGENT_IMPROVEMENTS.md             # Implementation code
QUICK_REFERENCE.md                # This file
```

---

## ⚙️ Environment Variables

### Required
```bash
OLLAMA_HOST=http://localhost:11434  # Or host.docker.internal:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
```

### Optional
```bash
DATABASE_URL=postgresql://user:pass@localhost:5432/db
MCP_URL=http://localhost:8080
MCP_API_KEY=your_key_here
OPENAI_API_KEY=sk-...
```

---

## 🚀 Common Commands

### Start System
```bash
docker compose up -d
```

### View Logs
```bash
docker compose logs -f streamlit-app
```

### Health Check (post-setup)
```bash
bash scripts/health_check.sh
```

What it checks:
- Streamlit health at `http://localhost:8501/_stcore/health`
- Ollama on host at `http://localhost:11434/api/tags`
- If Docker is available and container is running, connectivity from container to `http://host.docker.internal:11434`
- Prints a concise summary and suggested fixes

### Troubleshooting
- Refer to [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for error → fix mappings.

### Access App
```
http://localhost:8501
```

### Pull Ollama Models
```bash
ollama pull llama3
ollama pull nomic-embed-text
```

### Check Vector DB
```bash
# PostgreSQL
docker compose exec postgres psql -U ai_user -d ai_playground -c "SELECT COUNT(*) FROM document_embeddings;"

# JSON mode
cat data/memory/vector_store.json | jq '. | length'
```

---

## 🎯 Common Use Cases

### Use Case 1: Chat with a Document
```
1. Select "RAG Assistant" agent
2. Go to "Documents" page
3. Upload PDF/TXT/DOCX
4. Return to "Chat" page
5. Ask: "What are the key findings?"
```

### Use Case 2: Code Generation & Execution
```
1. Select "Coder (DeepSeek style)" agent
2. Ask: "Write a function to sort a list"
3. Agent writes code and can execute it
```

### Use Case 3: Multi-Document Research
```
1. Upload multiple documents
2. Select "Research Assistant"
3. Ask: "Compare approaches in doc1 vs doc2"
```

### Use Case 4: View Past Conversations
```
1. Go to "Conversations" page
2. Use search or tag filter
3. Click "Load" to restore conversation
```

---

## 🔧 Troubleshooting

### Documents Not Found in Search
```bash
# Check embeddings are stored
docker compose exec postgres psql -U ai_user -d ai_playground \
  -c "SELECT COUNT(*) FROM document_embeddings;"

# Verify Ollama is accessible
curl http://localhost:11434/api/tags
```

### MCP Not Connecting
```bash
# Check MCP server
curl http://localhost:8080/health

# Check logs
docker compose logs mcp-server
```

### Agent Not Using Tools
- Ensure agent has tools registered: Check `agent.tools` dict
- Verify LLM model supports JSON responses
- Check logs for tool execution errors

### Conversation Not Saving
- Check `data/memory/` directory exists
- Verify write permissions
- Look for errors in Streamlit logs

---

## 📊 Performance Tips

### Optimize Vector Search
```python
# Use smaller limit for faster searches
results = vector_db.search_similar(query, limit=3)  # Instead of 10

# Use PostgreSQL instead of JSON for large datasets
# Set DATABASE_URL in .env
```

### Reduce Token Usage
```python
# Use lower temperature for more focused responses
agent_config.temperature = 0.3  # Instead of 0.7

# Limit conversation history
agent.conversation_history = agent.conversation_history[-10:]  # Last 10 msgs
```

### Speed Up Document Processing
```python
# Use smaller chunks
doc_processor = DocumentProcessor(chunk_size=500)  # Instead of 1000

# Process in background
import threading
thread = threading.Thread(target=vector_db.store_document, args=(chunks, name))
thread.start()
```

---

## 🔐 Security Notes

### Code Execution
- `CodeExecutorTool` runs in restricted sandbox
- No file system or network access
- Limited Python builtins only

### API Keys
- Store in `.env` file (not committed to git)
- Never hardcode in source
- Use environment variables

### Vector DB
- Use parameterized queries (prevents SQL injection)
- Connection string in `.env`
- Consider access controls in production

---

## 📚 Learn More

| Topic | Document |
|-------|----------|
| Complete Guide | `docs/AI_AGENT_GUIDE.md` |
| Architecture | `docs/AGENT_ARCHITECTURE_DIAGRAM.md` |
| Implementation | `AGENT_IMPROVEMENTS.md` |
| Setup | `docs/SETUP.md` |
| Features | `docs/FEATURES.md` |

---

## 🎓 Code Snippets

### Create Custom Agent
```python
from agents.agent_system import Agent, AgentConfig, SearchTool

my_agent = Agent(
    AgentConfig(
        name="My Agent",
        system_prompt="You are a helpful assistant...",
        temperature=0.6
    ),
    tools=[SearchTool(vector_db)]
)

agent_registry.register(my_agent)
```

### Save Agent-Specific Conversation
```python
conv_id = memory.save_conversation(
    messages=st.session_state.messages,
    title="My conversation",
    tags=["RAG Assistant"],
    metadata={"agent_name": "RAG Assistant"}
)
```

### Upload Document with Agent Tag
```python
vector_db.store_document(
    chunks=chunks,
    document_name="report.pdf",
    metadata={"agent": "RAG Assistant"}
)
```

### Search Agent-Specific Documents
```python
results = vector_db.search_similar(
    query="key findings",
    limit=5,
    agent_filter="RAG Assistant"
)
```

### Load MCP Tools
```python
from agents.agent_system import load_mcp_tools

mcp_tools = load_mcp_tools(mcp_client)
agent.tools.update({t.name(): t for t in mcp_tools})
```

---

## 🆘 Getting Help

1. **Check logs**: `docker compose logs -f`
2. **Read guide**: `docs/AI_AGENT_GUIDE.md`
3. **Search issues**: Check GitHub issues
4. **Ask community**: Discord/Forum (if available)

---

## ✅ Checklist: First Time Setup

- [ ] Docker and Docker Compose installed
- [ ] Ollama installed and running
- [ ] Models pulled: `ollama pull llama3 nomic-embed-text`
- [ ] Environment variables in `.env`
- [ ] Containers started: `docker compose up -d`
- [ ] App accessible at `http://localhost:8501`
- [ ] Test document upload
- [ ] Test conversation saving
- [ ] Configure MCP (optional)

---

## 📈 System Status Dashboard

### Check Everything
```bash
# Services
docker compose ps

# Ollama
curl http://localhost:11434/api/tags

# PostgreSQL
docker compose exec postgres pg_isready

# Streamlit
curl http://localhost:8501/_stcore/health

# MCP (if configured)
curl http://localhost:8080/health
```

---

**Keep this reference handy while using the AI Agent Playground!**

For detailed information, see `docs/AI_AGENT_GUIDE.md`.
