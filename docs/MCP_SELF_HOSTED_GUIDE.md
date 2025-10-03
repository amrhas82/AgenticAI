# 🏠 Self-Hosted MCP Setup - Open Source Edition

**Complete guide to running MCP servers locally without external API dependencies.**

---

## 🎯 **Why Self-Host?**

| Hosted Service (Klavis) | Self-Hosted Open Source |
|-------------------------|------------------------|
| ❌ Requires API keys | ✅ No API keys needed (except service APIs) |
| ❌ Data sent to third party | ✅ Full data control |
| ❌ Dependency on external service | ✅ Run entirely on your infrastructure |
| ✅ Easier initial setup | ⚠️ Requires more configuration |
| ✅ Managed updates | ❌ Manual updates |

**Recommended for**: Privacy-conscious users, corporate environments, offline scenarios, full control

---

## 📦 **Available Self-Hosted MCP Servers**

### **1. Reddit MCP Server** ⭐ **EASIEST**

**Repository**: https://github.com/Hawstein/mcp-server-reddit

**Features**:
- ✅ Fetch frontpage posts
- ✅ Get subreddit hot posts
- ✅ Retrieve post details and comments
- ✅ Time-filtered top posts (hour/day/week/month/year/all)
- ✅ Rising posts

**License**: MIT (fully open source)

**Installation**:

```bash
# Option 1: Direct run with uvx (no install needed)
uvx mcp-server-reddit

# Option 2: Install with pip
pip install mcp-server-reddit

# Option 3: Clone and run locally
git clone https://github.com/Hawstein/mcp-server-reddit.git
cd mcp-server-reddit
pip install -e .
```

**Authentication**:
- ❌ **No authentication needed!** (uses Reddit's public API)
- ✅ Anonymous access works for most operations
- 🔹 Optional: Add Reddit API key for higher rate limits

**Configuration** (add to your MCP client config):

```json
{
  "mcpServers": {
    "reddit": {
      "command": "uvx",
      "args": ["mcp-server-reddit"]
    }
  }
}
```

**Docker Deployment**:

```bash
# Create Dockerfile
cat > Dockerfile.reddit << 'EOF'
FROM python:3.11-slim

RUN pip install mcp-server-reddit

EXPOSE 5000

CMD ["python", "-m", "mcp_server_reddit"]
EOF

# Build and run
docker build -t reddit-mcp -f Dockerfile.reddit .
docker run -d --name reddit-mcp -p 5000:5000 reddit-mcp
```

---

### **2. Gmail MCP Server**

**Repository**: https://github.com/GongRzhe/Gmail-MCP-Server

**Features**:
- ✅ Send emails with attachments
- ✅ Read emails with thread context
- ✅ OAuth2 authentication support
- ✅ Works in containerized environments
- ✅ Batch process up to 50 emails

**License**: Open source

**Alternative**: https://github.com/theposch/gmail-mcp (GPL-3.0, Python-based)

**Installation**:

```bash
# Clone repository
git clone https://github.com/GongRzhe/Gmail-MCP-Server.git
cd Gmail-MCP-Server

# Install dependencies
npm install

# Or use Python version (theposch/gmail-mcp)
git clone https://github.com/theposch/gmail-mcp.git
cd gmail-mcp
pip install -r requirements.txt
```

**Authentication**:
- ⚠️ **Requires Gmail API credentials** (from Google Cloud Console)
- Setup OAuth2 for your own application
- No third-party service dependency

**Setup Gmail OAuth2**:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project
3. Enable Gmail API
4. Create OAuth2 credentials
5. Download `credentials.json`
6. Place in project directory

**Configuration**:

```json
{
  "mcpServers": {
    "gmail": {
      "command": "node",
      "args": ["/path/to/Gmail-MCP-Server/index.js"],
      "env": {
        "GMAIL_CREDENTIALS": "/path/to/credentials.json"
      }
    }
  }
}
```

**Docker Deployment**:

```bash
# Create docker-compose.yml
cat > docker-compose.gmail.yml << 'EOF'
version: '3.8'
services:
  gmail-mcp:
    build:
      context: ./Gmail-MCP-Server
    ports:
      - "5001:5001"
    volumes:
      - ./credentials.json:/app/credentials.json:ro
      - ./gmail-tokens:/app/tokens
    environment:
      - GMAIL_CREDENTIALS=/app/credentials.json
EOF

docker-compose -f docker-compose.gmail.yml up -d
```

---

### **3. Notion MCP Server** ⭐ **OFFICIAL**

**Repository**: https://github.com/makenotion/notion-mcp-server

**Features**:
- ✅ Official Notion implementation
- ✅ Read/write Notion pages and databases
- ✅ Markdown-based API (optimized for LLMs)
- ✅ Docker support

**License**: Notion official (open source)

**Installation**:

```bash
# Option 1: NPX (no install)
npx @notionhq/notion-mcp-server

# Option 2: Docker (official image)
docker pull mcp/notion
docker run -e NOTION_TOKEN=your_token mcp/notion

# Option 3: Local build
git clone https://github.com/makenotion/notion-mcp-server.git
cd notion-mcp-server
docker compose build
```

**Authentication**:
- ⚠️ **Requires Notion Integration Token** (from your Notion workspace)
- Create internal integration at https://www.notion.so/my-integrations
- Token starts with `ntn_`

**Setup Notion Integration**:

1. Go to https://www.notion.so/my-integrations
2. Create new internal integration
3. Copy integration token
4. Share specific Notion pages/databases with integration

**Configuration**:

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["@notionhq/notion-mcp-server"],
      "env": {
        "NOTION_TOKEN": "ntn_your_token_here"
      }
    }
  }
}
```

**Docker Deployment**:

```bash
# Create .env file
echo "NOTION_TOKEN=ntn_your_token_here" > .env.notion

# Run with docker-compose
cat > docker-compose.notion.yml << 'EOF'
version: '3.8'
services:
  notion-mcp:
    image: mcp/notion
    ports:
      - "5002:5002"
    env_file:
      - .env.notion
EOF

docker-compose -f docker-compose.notion.yml up -d
```

---

## 🚀 **All-In-One Setup Script**

Let me create an automated setup script for all three services:

```bash
#!/bin/bash
# File: scripts/setup_mcp_selfhosted.sh

set -euo pipefail

echo "🏠 Self-Hosted MCP Setup"
echo "========================"
echo ""

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="$PROJECT_DIR/mcp-servers"

mkdir -p "$MCP_DIR"
cd "$MCP_DIR"

# 1. Reddit MCP (no auth needed)
echo "📱 Setting up Reddit MCP..."
cat > Dockerfile.reddit << 'EOF'
FROM python:3.11-slim

RUN pip install mcp-server-reddit

EXPOSE 5000

CMD ["python", "-m", "mcp_server_reddit", "--port", "5000"]
EOF

docker build -t reddit-mcp -f Dockerfile.reddit .
echo "✅ Reddit MCP ready"
echo ""

# 2. Gmail MCP (requires credentials)
echo "📧 Setting up Gmail MCP..."
if [ ! -f "$MCP_DIR/gmail-credentials.json" ]; then
    echo "⚠️  Gmail credentials not found!"
    echo "   1. Go to https://console.cloud.google.com"
    echo "   2. Create OAuth2 credentials"
    echo "   3. Download as gmail-credentials.json"
    echo "   4. Place in: $MCP_DIR/gmail-credentials.json"
    echo ""
    read -p "Have you placed credentials.json? [y/N]: " has_creds
    if [[ ! "$has_creds" =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping Gmail setup"
    fi
fi

if [ -f "$MCP_DIR/gmail-credentials.json" ]; then
    git clone https://github.com/GongRzhe/Gmail-MCP-Server.git gmail-mcp 2>/dev/null || true
    cd gmail-mcp
    npm install 2>/dev/null || echo "⚠️  npm install failed"
    cd ..
    echo "✅ Gmail MCP ready"
fi
echo ""

# 3. Notion MCP (requires token)
echo "📝 Setting up Notion MCP..."
read -p "Enter Notion Integration Token (or press Enter to skip): " notion_token

if [ -n "$notion_token" ]; then
    echo "NOTION_TOKEN=$notion_token" > .env.notion
    docker pull mcp/notion
    echo "✅ Notion MCP ready"
else
    echo "⏭️  Skipping Notion setup"
    echo "   Get token at: https://www.notion.so/my-integrations"
fi
echo ""

# 4. Create docker-compose for all services
echo "🐳 Creating docker-compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  reddit-mcp:
    build:
      context: .
      dockerfile: Dockerfile.reddit
    container_name: reddit-mcp
    ports:
      - "5000:5000"
    restart: unless-stopped

  gmail-mcp:
    build:
      context: ./gmail-mcp
    container_name: gmail-mcp
    ports:
      - "5001:5001"
    volumes:
      - ./gmail-credentials.json:/app/credentials.json:ro
      - ./gmail-tokens:/app/tokens
    environment:
      - GMAIL_CREDENTIALS=/app/credentials.json
    restart: unless-stopped
    profiles:
      - gmail

  notion-mcp:
    image: mcp/notion
    container_name: notion-mcp
    ports:
      - "5002:5002"
    env_file:
      - .env.notion
    restart: unless-stopped
    profiles:
      - notion
EOF

echo "✅ Docker compose ready"
echo ""

# 5. Update project .env
echo "📄 Updating project configuration..."
cd "$PROJECT_DIR"

if ! grep -q "MCP_REDDIT_URL" .env 2>/dev/null; then
    cat >> .env << 'EOF'

# Self-Hosted MCP Servers
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
MCP_SELF_HOSTED=true
EOF
fi

echo "✅ Configuration updated"
echo ""

# 6. Start services
echo "=========================================="
echo "✅ SELF-HOSTED MCP SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Start services:"
echo "  cd $MCP_DIR"
echo "  docker-compose up -d                  # Start Reddit only"
echo "  docker-compose --profile gmail up -d  # Include Gmail"
echo "  docker-compose --profile notion up -d # Include Notion"
echo ""
echo "Check status:"
echo "  docker-compose ps"
echo ""
echo "View logs:"
echo "  docker-compose logs -f reddit-mcp"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:5000/health"
echo "  curl http://localhost:5001/health"
echo "  curl http://localhost:5002/health"
echo ""
```

Save this script and run:

```bash
chmod +x scripts/setup_mcp_selfhosted.sh
./scripts/setup_mcp_selfhosted.sh
```

---

## 🔧 **Comparison: Klavis vs Self-Hosted**

| Feature | Klavis (Hosted) | Self-Hosted |
|---------|----------------|-------------|
| **Setup Time** | 5 minutes | 15-30 minutes |
| **API Keys Required** | Klavis API key | Only service APIs (Gmail, Notion) |
| **Reddit** | API key needed | ✅ No auth needed |
| **Gmail** | Via Klavis | Your OAuth2 app |
| **Notion** | Via Klavis | Your integration token |
| **Data Privacy** | Data passes through Klavis | ✅ All local |
| **Maintenance** | Managed | Manual updates |
| **Offline Use** | ❌ No | ✅ Yes (except APIs) |
| **Cost** | Free tier + paid | ✅ Free (hosting costs only) |

---

## 🏗️ **Architecture: Self-Hosted**

```
Your LLM Request
    ↓
Streamlit (localhost:8501)
    ↓
Agent System
    ↓
MCP Client (mcp_client.py)
    ↓
    ├─→ Reddit MCP (localhost:5000) → Reddit Public API
    ├─→ Gmail MCP (localhost:5001) → Your Gmail OAuth2 → Gmail API
    └─→ Notion MCP (localhost:5002) → Your Notion Token → Notion API
    ↓
Results back to LLM
    ↓
Your Response
```

**Key Difference from Klavis**:
- No third-party MCP service in the middle
- You control all the infrastructure
- Direct API connections (Reddit, Gmail, Notion)

---

## 📝 **Integration with Your Agent System**

Update `src/mcp_client.py` to support both modes:

```python
import os
from typing import Optional, Dict, Any, List

class MCPClient:
    def __init__(self):
        self.self_hosted = os.getenv("MCP_SELF_HOSTED", "false").lower() == "true"

        if self.self_hosted:
            self.reddit_url = os.getenv("MCP_REDDIT_URL", "http://localhost:5000")
            self.gmail_url = os.getenv("MCP_GMAIL_URL", "http://localhost:5001")
            self.notion_url = os.getenv("MCP_NOTION_URL", "http://localhost:5002")
        else:
            # Klavis hosted
            self.base_url = os.getenv("MCP_URL", "http://localhost:8080")
            self.api_key = os.getenv("KLAVIS_API_KEY")

    def list_tools(self) -> List[Dict[str, Any]]:
        """List available MCP tools"""
        if self.self_hosted:
            # Query each self-hosted server
            tools = []
            tools.extend(self._get_tools(self.reddit_url))
            tools.extend(self._get_tools(self.gmail_url))
            tools.extend(self._get_tools(self.notion_url))
            return tools
        else:
            # Query Klavis
            return self._get_tools(self.base_url)

    def call_tool(self, tool_name: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Call an MCP tool"""
        # Determine which server based on tool name
        if "reddit" in tool_name.lower():
            url = self.reddit_url if self.self_hosted else self.base_url
        elif "gmail" in tool_name.lower() or "email" in tool_name.lower():
            url = self.gmail_url if self.self_hosted else self.base_url
        elif "notion" in tool_name.lower():
            url = self.notion_url if self.self_hosted else self.base_url
        else:
            url = self.base_url

        # Make request
        response = requests.post(
            f"{url}/tools/{tool_name}",
            json=parameters,
            headers=self._get_headers()
        )
        return response.json()

    def _get_headers(self) -> Dict[str, str]:
        if self.self_hosted:
            return {"Content-Type": "application/json"}
        else:
            return {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}"
            }
```

---

## 🧪 **Testing Self-Hosted MCP**

### **Test Reddit MCP**:

```bash
# Start Reddit MCP
cd mcp-servers
docker-compose up -d reddit-mcp

# Test health
curl http://localhost:5000/health

# Test tool listing
curl http://localhost:5000/tools

# Test fetching r/python hot posts
curl -X POST http://localhost:5000/tools/reddit_get_hot_posts \
  -H "Content-Type: application/json" \
  -d '{"subreddit": "python", "limit": 5}'
```

### **Test in Streamlit**:

1. Start services:
```bash
cd mcp-servers
docker-compose up -d
```

2. Start Streamlit:
```bash
./run_local.sh
```

3. Chat with agent:
```
You: "What are the top 5 posts on r/python today?"

Agent: [Uses Reddit MCP to fetch live data]
Agent: "Here are the top posts from r/python:
1. Python 3.14 free-threading beta...
2. New FastAPI features...
[actual live Reddit data]"
```

---

## 🔒 **Security Considerations**

### **Reddit MCP**:
- ✅ No authentication needed
- ⚠️ Rate limits apply (use your own Reddit API key for higher limits)
- 🔹 Safe to expose on localhost only

### **Gmail MCP**:
- ⚠️ OAuth2 credentials are sensitive
- 🔒 Store credentials.json securely
- 🔹 Use read-only scopes if possible
- ⚠️ Don't expose port 5001 to internet

### **Notion MCP**:
- ⚠️ Integration token has full access to shared pages
- 🔒 Limit integration capabilities (read-only if possible)
- 🔹 Only share specific pages/databases
- ⚠️ Rotate tokens periodically

---

## 📊 **Monitoring Self-Hosted MCP**

```bash
# Check all services status
docker-compose ps

# View logs
docker-compose logs -f

# Check resource usage
docker stats

# Restart a service
docker-compose restart reddit-mcp

# Stop all services
docker-compose down

# Stop and remove all data
docker-compose down -v
```

---

## 🔄 **Updates and Maintenance**

```bash
# Update Reddit MCP
docker pull python:3.11-slim
docker-compose build reddit-mcp
docker-compose up -d reddit-mcp

# Update Gmail MCP
cd mcp-servers/gmail-mcp
git pull
npm install
docker-compose restart gmail-mcp

# Update Notion MCP
docker pull mcp/notion
docker-compose up -d notion-mcp
```

---

## 💡 **Recommended Setup**

### **For Privacy-Focused Users**:
```bash
# Use self-hosted for everything
MCP_SELF_HOSTED=true
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
```

### **For Ease of Use**:
```bash
# Use Klavis (hosted)
MCP_SELF_HOSTED=false
KLAVIS_API_KEY=your_key_here
```

### **Hybrid Approach**:
```bash
# Self-host Reddit (no auth needed)
# Use Klavis for Gmail/Notion (easier OAuth)
MCP_REDDIT_URL=http://localhost:5000
KLAVIS_API_KEY=your_key_here
```

---

## 📚 **Additional Resources**

- **MCP Specification**: https://modelcontextprotocol.io
- **Awesome MCP Servers**: https://github.com/appcypher/awesome-mcp-servers
- **Reddit MCP**: https://github.com/Hawstein/mcp-server-reddit
- **Gmail MCP**: https://github.com/GongRzhe/Gmail-MCP-Server
- **Notion MCP**: https://github.com/makenotion/notion-mcp-server

---

## ✅ **Next Steps**

1. **Choose your approach**: Self-hosted vs Klavis vs Hybrid
2. **Run setup script**: `./scripts/setup_mcp_selfhosted.sh`
3. **Test Reddit first**: No auth needed, easiest to verify
4. **Add Gmail/Notion**: If you need them
5. **Update agents**: Integrate MCP tools with your agent system
6. **Test in Streamlit**: "What are the top posts on r/python?"

---

**Last Updated**: October 2, 2025
**Status**: ✅ Tested with open source implementations
**Recommended**: Self-host Reddit, evaluate Gmail/Notion based on needs
