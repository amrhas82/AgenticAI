# MCP Setup & Web Access - Complete Guide

**Questions Answered:**
1. How to set up Klavis MCP (Reddit, Notion, Gmail)?
2. Can local LLMs access the internet?

---

## 🌐 **Q: Can Local LLMs Access the Internet?**

### **Short Answer: NO** ❌

Your local LLMs (deepseek-coder, qwen2.5-coder, llama3.2) **CANNOT** access the internet directly.

### **Why Not?**

Local LLMs are:
- ✅ **Trained on data** (up to their training cutoff date)
- ✅ **Run entirely offline** (just text in → text out)
- ❌ **Cannot make HTTP requests**
- ❌ **Cannot browse websites**
- ❌ **Cannot check live data**
- ❌ **Cannot access APIs**

### **What They Know:**

```
deepseek-coder knows:
✅ How to write Python code
✅ Common programming patterns
✅ General knowledge from training data
❌ Current weather
❌ Latest news
❌ Your emails
❌ Reddit posts from today
```

---

## 🔧 **How to Give LLMs Internet Access?**

### **Option 1: Use MCP (Model Context Protocol)** ⭐ **RECOMMENDED**

MCP servers act as **tools** that your LLM can use:

```
Your Prompt → LLM → Decides to use tool → MCP Server → Internet/API
                ↑                              ↓
                └──────── Returns data ────────┘
                ↓
            LLM processes result → Your Answer
```

**Example:**
```
You: "What's the top post on r/python today?"
LLM: [calls Reddit MCP tool]
Reddit MCP: [fetches from Reddit API]
LLM: "The top post is about Python 3.13..."
```

---

## 🚀 **Setting Up MCP (Reddit, Notion, Gmail)**

### **Two Options:**

#### **Option 1: Self-Hosted (Open Source)** ⭐ **RECOMMENDED**

**Advantages:**
- ✅ Full privacy - all data stays local
- ✅ No external API dependencies (except service APIs)
- ✅ Reddit works with zero authentication
- ✅ Complete control

**Quick Setup:**
```bash
cd /home/hamr/PycharmProjects/AgenticAI
./scripts/setup_mcp_selfhosted.sh
```

📚 **Full Guide**: See `MCP_SELF_HOSTED_GUIDE.md` for complete documentation

---

#### **Option 2: Klavis (Hosted Service)**

**Prerequisites:**

1. **Docker installed** (for MCP servers)
2. **API keys** (for some services)
3. **Klavis account** (free at https://klavis.ai)

**Quick Setup:**

```bash
cd /home/hamr/PycharmProjects/AgenticAI
./scripts/setup_klavis_mcp.sh
```

**What it installs:**
- ✅ Reddit MCP (port 5000) - Requires Klavis API key
- ✅ Gmail MCP (port 5001) - Requires Klavis API key
- ✅ Notion MCP (port 5002) - Requires Klavis API key

---

### **Detailed Setup Steps:**

#### **Step 1: Get Klavis API Key**

```bash
# Go to:
https://klavis.ai

# Sign up (free)
# Go to dashboard → API Keys
# Copy your API key
```

#### **Step 2: Run Setup Script**

```bash
./scripts/setup_klavis_mcp.sh
```

**Script will:**
1. Pull Docker images from Klavis
2. Start MCP servers as containers
3. Configure `.env` with URLs
4. Create integration guide

#### **Step 3: Verify Installation**

```bash
# Check containers are running
docker ps | grep mcp

# Should show:
# reddit-mcp    (port 5000)
# gmail-mcp     (port 5001)
# notion-mcp    (port 5002)
```

#### **Step 4: Test MCP Servers**

```bash
# Test Reddit MCP
curl http://localhost:5000/health
# Should return: {"status": "ok"}

# Test Gmail MCP
curl http://localhost:5001/health
# Should return: {"status": "ok"}

# Test Notion MCP
curl http://localhost:5002/health
# Should return: {"status": "ok"}
```

---

## 🔗 **Available MCP Servers:**

| Service | Port | Auth Required | Use Case |
|---------|------|---------------|----------|
| **Reddit** | 5000 | ❌ No | Browse subreddits, get posts |
| **Gmail** | 5001 | ✅ API Key | Read/send emails |
| **Notion** | 5002 | ✅ API Key | Access Notion pages/databases |
| **GitHub** | 5003 | ✅ API Key | Check repos, issues, PRs |
| **Slack** | 5004 | ✅ API Key | Send messages, read channels |
| **YouTube** | 5005 | ❌ No | Search videos, get info |

**50+ more available at**: https://github.com/Klavis-AI/klavis

---

## 🛠️ **How MCP Integrates with Your Agents:**

### **Current Setup (Without MCP):**

```
You → Streamlit → Agent → LLM → Response
                           ↓
                    (no tools, no internet)
```

### **With MCP Enabled:**

```
You → Streamlit → Agent → LLM → "Need to check Reddit"
                           ↓
                    Calls Reddit MCP tool
                           ↓
                    Reddit API → Latest posts
                           ↓
                    LLM processes data
                           ↓
                    Final response with live data
```

---

## 📝 **Configuration After Setup:**

Your `.env` file will have:

```bash
# Existing
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text

# New MCP URLs
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
KLAVIS_API_KEY=your_actual_key_here
```

---

## 🔧 **Using MCP in Your Code:**

### **Option A: Via mcp_client.py** (Already in your codebase)

```python
from mcp_client import MCPClient

# Initialize
mcp = MCPClient()

# List available tools
tools = mcp.list_tools()
print(tools)  # Shows Reddit, Gmail, Notion tools

# Call a tool
result = mcp.call_tool(
    tool_name="reddit_get_top_posts",
    parameters={"subreddit": "python", "limit": 5}
)
```

### **Option B: Via Klavis SDK**

```python
from klavis import Klavis

klavis = Klavis(api_key="your_key")

# Use Gmail
response = klavis.gmail.list_messages(max_results=10)

# Use Reddit
posts = klavis.reddit.get_subreddit("python").hot(limit=5)

# Use Notion
pages = klavis.notion.query_database("database_id")
```

---

## 🎯 **When Do You Need MCP?**

### **WITHOUT MCP (Current):**
✅ Write code
✅ Explain concepts
✅ Debug static code
✅ Answer from training data

### **WITH MCP (After Setup):**
✅ Check Reddit for latest posts
✅ Read/send Gmail
✅ Access Notion databases
✅ Get live GitHub issues
✅ Search YouTube
✅ **Any live internet data!**

---

## 🚦 **MCP Setup Status:**

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1-2** | ✅ Complete | Basic chat working, models installed |
| **Phase 3** | ⏳ Next | Document upload & RAG |
| **Phase 4** | 🔜 TODO | **MCP Integration** |
| **Phase 5** | 🔜 TODO | Windows setup |

---

## 🎓 **Analogy:**

**LLM without MCP:**
- Like a very smart person locked in a room with no phone/internet
- Knows a lot from memory
- Can't check current information

**LLM with MCP:**
- Same smart person but with a phone and internet
- Can look things up
- Can interact with apps (Gmail, Reddit, etc.)
- Can get live data

---

## 🔍 **Real Example:**

### **Without MCP:**
```
You: "What's the latest news on Python 3.14?"
LLM: "I don't have access to current information.
     Based on my training data up to 2024..."
```

### **With MCP (Reddit tool):**
```
You: "What's the latest news on Python 3.14?"
LLM: [Uses Reddit MCP to check r/python]
LLM: "From r/python today, the top discussions about
     Python 3.14 include:
     1. Free-threading improvements...
     2. Performance benchmarks...
     [actual live data]"
```

---

## ⚙️ **MCP Server Management:**

### **Start All MCP Servers:**
```bash
docker start reddit-mcp gmail-mcp notion-mcp
```

### **Stop All MCP Servers:**
```bash
docker stop reddit-mcp gmail-mcp notion-mcp
```

### **View Logs:**
```bash
docker logs -f reddit-mcp
docker logs -f gmail-mcp
docker logs -f notion-mcp
```

### **Restart After Configuration Change:**
```bash
docker restart reddit-mcp gmail-mcp notion-mcp
```

---

## 🐛 **Troubleshooting:**

### **"Cannot connect to MCP server"**
```bash
# Check if running
docker ps | grep mcp

# Start if stopped
docker start reddit-mcp gmail-mcp notion-mcp
```

### **"API key invalid"**
```bash
# Update .env with correct key
nano .env
# Change KLAVIS_API_KEY=your_actual_key

# Restart containers
docker restart gmail-mcp notion-mcp
```

### **"Port already in use"**
```bash
# Find what's using the port
sudo lsof -i :5000

# Kill it or change MCP port
docker stop reddit-mcp
docker rm reddit-mcp
docker run -d --name reddit-mcp -p 5010:5000 ghcr.io/klavis-ai/reddit-mcp-server
```

---

## 📊 **Summary:**

### **Question 1: MCP Setup (Reddit, Notion, Gmail)**

**Answer:**
```bash
# 1. Get API key from https://klavis.ai
# 2. Run setup
./scripts/setup_klavis_mcp.sh

# 3. Verify
docker ps | grep mcp
```

### **Question 2: Can Local LLMs Access Internet?**

**Answer:**
- ❌ **NO** - Not by default
- ✅ **YES** - With MCP tools (acts as their "hands")

**Workflow:**
```
Local LLM (brain) → MCP Server (hands) → Internet/APIs
```

---

## 🚀 **Next Steps:**

### **Now (Phase 2 - Complete):**
- ✅ Basic chat working
- ✅ 3 coding models installed
- ✅ Fast responses (3-5s)

### **Phase 3 (Next):**
- Test document upload
- Verify RAG with nomic-embed-text
- Search over your documents

### **Phase 4 (MCP):**
1. Run `./scripts/setup_klavis_mcp.sh`
2. Get Klavis API key
3. Test Reddit MCP first (no auth needed)
4. Add Gmail/Notion with API key
5. Test with agents

---

## 📚 **References:**

- Klavis GitHub: https://github.com/Klavis-AI/klavis
- Klavis Docs: https://docs.klavis.ai
- Your setup script: `./scripts/setup_klavis_mcp.sh`
- MCP quickstart: `docs/KLAVIS_MCP_QUICKSTART.md`

---

**Key Takeaway:**
- Local LLMs = Offline, no internet
- MCP = Gives them tools to access internet
- Setup = Run one script, add API keys

**Ready to add internet access to your local LLM? Run the MCP setup in Phase 4!** 🚀
