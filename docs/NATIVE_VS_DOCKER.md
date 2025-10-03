# Native Mode vs Docker Mode - Explained

## 🎯 **Quick Answer:**

**You're currently running in NATIVE MODE** (no Docker)

---

## 📊 **Comparison Table:**

| Feature | Native Mode (`./run_local.sh`) | Docker Mode (`./setup.sh` or `docker-compose up`) |
|---------|-------------------------------|---------------------------------------------------|
| **What runs where** | Everything on host machine | Streamlit + PostgreSQL in containers |
| **Ollama** | ✅ On host (localhost:11434) | ✅ On host (accessed via host.docker.internal) |
| **Streamlit** | ✅ On host (~/.local/bin/streamlit) | 🐳 In Docker container |
| **PostgreSQL** | ❌ Not used (JSON storage) | 🐳 In Docker container (pgvector) |
| **Python dependencies** | ✅ Installed on host (~/.local/lib) | 🐳 Inside container |
| **Complexity** | ⭐ Simple | ⭐⭐⭐ Complex |
| **Startup time** | Fast (~5 seconds) | Slow (~30-60 seconds) |
| **Memory usage** | Low (~300MB for Streamlit) | Medium (~1GB for containers) |
| **Best for** | Development, testing, single user | Production, multi-user, isolation |

---

## 🔍 **Current Setup (Native Mode):**

```
┌─────────────────────────────────────┐
│         Your Linux Machine          │
│                                     │
│  ┌───────────────┐                 │
│  │   Ollama      │ :11434          │
│  │  (Host)       │                 │
│  └───────┬───────┘                 │
│          │                          │
│          ├──> deepseek-coder:1.3b  │
│          ├──> qwen2.5-coder:1.5b   │
│          └──> qwen2.5-coder:3b     │
│                                     │
│  ┌───────────────┐                 │
│  │  Streamlit    │ :8501           │
│  │  (Host)       │                 │
│  └───────┬───────┘                 │
│          │                          │
│          ↓                          │
│  ┌───────────────┐                 │
│  │  Python App   │                 │
│  │  (src/app.py) │                 │
│  └───────┬───────┘                 │
│          │                          │
│          ↓                          │
│  ┌───────────────┐                 │
│  │  JSON Storage │                 │
│  │  (./data/)    │                 │
│  └───────────────┘                 │
└─────────────────────────────────────┘
```

**Processes running:**
```bash
ollama serve              # PID 1749
streamlit run src/app.py  # PID 148547
```

---

## 🐳 **Docker Mode (Not Currently Running):**

```
┌─────────────────────────────────────┐
│         Your Linux Machine          │
│                                     │
│  ┌───────────────┐                 │
│  │   Ollama      │ :11434          │
│  │  (Host)       │                 │
│  └───────┬───────┘                 │
│          │                          │
│          ↑                          │
│   via host.docker.internal         │
│          │                          │
│  ┌───────┴────────────────────┐   │
│  │  Docker Network            │   │
│  │                            │   │
│  │  ┌──────────────────────┐ │   │
│  │  │ Streamlit Container  │ │   │
│  │  │ :8501                │ │   │
│  │  │                      │ │   │
│  │  │ - Python 3.11        │ │   │
│  │  │ - Streamlit          │ │   │
│  │  │ - App code           │ │   │
│  │  └──────────┬───────────┘ │   │
│  │             │              │   │
│  │             ↓              │   │
│  │  ┌──────────────────────┐ │   │
│  │  │ PostgreSQL Container │ │   │
│  │  │ :5432                │ │   │
│  │  │                      │ │   │
│  │  │ - pgvector extension │ │   │
│  │  │ - Vector storage     │ │   │
│  │  └──────────────────────┘ │   │
│  └────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Processes running (when Docker mode active):**
```bash
ollama serve                           # On host
docker compose up                      # Container manager
  └─> streamlit-app container          # Streamlit in Docker
  └─> postgres container                # PostgreSQL in Docker
```

---

## 🤔 **Why Two Modes?**

### **Native Mode** (`./run_local.sh`) - **What you're using now**

**Pros:**
- ✅ **Simple**: No Docker needed
- ✅ **Fast**: Direct execution, no container overhead
- ✅ **Easy debugging**: Direct access to logs
- ✅ **Lightweight**: Only uses what you need
- ✅ **Works on any Linux**: No Docker Desktop required

**Cons:**
- ❌ No PostgreSQL (uses JSON files for storage)
- ❌ No vector database optimizations
- ❌ Not isolated (Python packages on host)
- ❌ Single user only

**Best for:**
- Development
- Testing
- Personal use
- Learning
- Your current use case ✅

---

### **Docker Mode** (`docker-compose up`)

**Pros:**
- ✅ **PostgreSQL + pgvector**: Real database with vector search
- ✅ **Isolated**: Containers don't affect host
- ✅ **Reproducible**: Same environment everywhere
- ✅ **Multi-user**: Better for production
- ✅ **Easy cleanup**: `docker-compose down` removes everything

**Cons:**
- ❌ **Complex**: Requires Docker knowledge
- ❌ **Slower**: Container startup time
- ❌ **More memory**: ~1GB+ for containers
- ❌ **Networking issues**: host.docker.internal on Linux can be tricky
- ❌ **Docker Desktop**: May require paid license on some systems

**Best for:**
- Production deployment
- Multiple users
- Advanced RAG with large document collections
- CI/CD pipelines
- Team environments

---

## 🎯 **Which Mode Should You Use?**

### **Use Native Mode (`./run_local.sh`) if:**
- ✅ You're developing/testing
- ✅ Single user (just you)
- ✅ Don't need PostgreSQL
- ✅ Want simple and fast
- ✅ Limited RAM/resources
- ✅ **This is what you're doing now!** ✅

### **Use Docker Mode (`docker-compose up`) if:**
- ❌ Multiple users need access
- ❌ Need PostgreSQL + pgvector
- ❌ Want isolated environment
- ❌ Deploying to production
- ❌ Working in a team

---

## 🔄 **Switching Between Modes:**

### **Currently (Native) → Docker:**
```bash
# Stop native mode
pkill streamlit
# (Ollama keeps running)

# Start Docker mode
docker-compose up -d

# Ollama on host will be accessed from containers via host.docker.internal
```

### **Docker → Native (What we did today):**
```bash
# Stop Docker mode
docker-compose down

# Start native mode
./run_local.sh
```

---

## 📝 **Data Storage:**

### **Native Mode:**
```
./data/
├── conversations/       # JSON files (conversation history)
├── documents/          # Uploaded files
├── uploads/            # Temporary uploads
└── db/                 # JSON-based vector storage
```

### **Docker Mode:**
```
PostgreSQL container:
└─> ai_playground database
    ├── conversations table
    ├── documents table
    └── vectors table (with pgvector extension)

Plus same ./data/ folder for files
```

---

## ⚙️ **Configuration Differences:**

### **Native Mode (.env):**
```bash
OLLAMA_HOST=http://localhost:11434     # Direct access
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://localhost:8080
# No DATABASE_URL (uses JSON)
```

### **Docker Mode (docker-compose.yml env):**
```bash
OLLAMA_HOST=http://host.docker.internal:11434  # Via Docker network
DATABASE_URL=postgresql://ai_user:ai_password@postgres:5432/ai_playground
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://host.docker.internal:8080
```

---

## 🚀 **Performance:**

| Metric | Native Mode | Docker Mode |
|--------|-------------|-------------|
| **Startup** | 5 seconds | 30-60 seconds |
| **Memory** | ~300MB | ~1GB+ |
| **LLM Speed** | Same (both use host Ollama) | Same |
| **DB queries** | Fast (JSON in memory) | Faster (PostgreSQL) |
| **Vector search** | Good (JSON) | Better (pgvector) |

---

## 💡 **Key Insight:**

**Ollama ALWAYS runs on the host in both modes!**

Why?
- Ollama needs direct GPU/CPU access for inference
- Models are large (GBs) and stored on host
- Container overhead would slow down inference
- Host has your models already downloaded

**Only Streamlit and PostgreSQL run in Docker (when using Docker mode)**

---

## ✅ **Your Current Setup (Native Mode):**

```bash
# Check what's running
ps aux | grep -E "(streamlit|ollama)"

# Should show:
# ollama serve                    <- On host
# streamlit run src/app.py        <- On host

# No Docker containers
docker ps
# Should show: (empty)
```

---

## 🎓 **Summary:**

You're using **Native Mode** because:
1. ✅ Simpler for development
2. ✅ Faster startup
3. ✅ Less memory usage
4. ✅ Easier to debug
5. ✅ Don't need PostgreSQL yet

**When to switch to Docker:**
- Testing PostgreSQL integration
- Need advanced vector search
- Deploying to production
- Working with a team

For now, **stick with Native Mode** - it's perfect for your use case!

---

**Questions?** Ask away! 🚀
