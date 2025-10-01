# Klavis MCP - Quick Start

**Last Updated**: October 1, 2025  
**Based on**: https://github.com/Klavis-AI/klavis

---

## 🚀 One-Command Setup

```bash
./scripts/setup_klavis_mcp.sh
```

This will:
1. ✅ Install Reddit MCP Server
2. ✅ Install Gmail MCP Server (requires API key)
3. ✅ Install Notion MCP Server
4. ✅ Configure environment variables
5. ✅ Create integration guide

**Time**: 5-10 minutes

---

## What Gets Installed

### Reddit MCP
- **Container**: `reddit-mcp`
- **Port**: 5000
- **URL**: http://localhost:5000
- **Image**: `ghcr.io/klavis-ai/reddit-mcp-server:latest`

### Gmail MCP
- **Container**: `gmail-mcp`
- **Port**: 5001
- **URL**: http://localhost:5001
- **Image**: `ghcr.io/klavis-ai/gmail-mcp-server:latest`
- **Requires**: Klavis API key from https://klavis.ai/

### Notion MCP
- **Container**: `notion-mcp`
- **Port**: 5002
- **URL**: http://localhost:5002
- **Image**: `ghcr.io/klavis-ai/notion-mcp-server:latest`

---

## Quick Commands

### Check Services
```bash
docker ps | grep mcp
```

### View Logs
```bash
docker logs -f reddit-mcp
docker logs -f gmail-mcp
docker logs -f notion-mcp
```

### Stop/Start
```bash
# Stop all
docker stop reddit-mcp gmail-mcp notion-mcp

# Start all
docker start reddit-mcp gmail-mcp notion-mcp
```

---

## Environment Variables

After running the script, `.env` will contain:

```bash
# Klavis MCP Configuration
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
KLAVIS_API_KEY=your_key_here
```

---

## How to Add More Services

Klavis provides 50+ MCP servers. To add more:

### Option 1: Re-run Setup Script
```bash
./scripts/setup_klavis_mcp.sh
# Script will detect existing services
```

### Option 2: Manual Installation

Example - Add GitHub MCP:

```bash
# 1. Run container
docker run -d \
  --name github-mcp \
  -p 5003:5000 \
  --restart unless-stopped \
  ghcr.io/klavis-ai/github-mcp-server:latest

# 2. Add to .env
echo "MCP_GITHUB_URL=http://localhost:5003" >> .env

# 3. Restart app
docker compose restart streamlit-app
```

### Available Services

Popular options:
- **GitHub**: `ghcr.io/klavis-ai/github-mcp-server`
- **Slack**: `ghcr.io/klavis-ai/slack-mcp-server`
- **YouTube**: `ghcr.io/klavis-ai/youtube-mcp-server`
- **Twitter**: `ghcr.io/klavis-ai/twitter-mcp-server`
- **Discord**: `ghcr.io/klavis-ai/discord-mcp-server`
- **Linear**: `ghcr.io/klavis-ai/linear-mcp-server`
- **Jira**: `ghcr.io/klavis-ai/jira-mcp-server`

Full list: https://github.com/Klavis-AI/klavis

---

## Integration with AI Agents

### 1. Install Klavis Client
```bash
pip install klavis
```

### 2. Use in Python
```python
from klavis import KlavisClient
import os

# Connect to services
reddit = KlavisClient(base_url=os.getenv('MCP_REDDIT_URL'))
gmail = KlavisClient(
    base_url=os.getenv('MCP_GMAIL_URL'),
    api_key=os.getenv('KLAVIS_API_KEY')
)
notion = KlavisClient(base_url=os.getenv('MCP_NOTION_URL'))
```

### 3. Integration Guide

See `KLAVIS_MCP_GUIDE.md` for:
- Creating Klavis tools for agents
- Adding to agent system
- Code examples
- Troubleshooting

---

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs <container-name>

# Check if port is in use
sudo lsof -i :5000
```

### Need API Key
Get from: https://klavis.ai/

### Image Not Found
Check: https://github.com/orgs/Klavis-AI/packages

---

## Documentation

| Document | Purpose |
|----------|---------|
| **KLAVIS_MCP_QUICKSTART.md** | This file - quick start |
| **KLAVIS_MCP_GUIDE.md** | Complete integration guide |
| **scripts/setup_klavis_mcp.sh** | Automated setup script |

---

## What Was Deleted

✅ Deleted old incorrect scripts:
- ~~`scripts/setup_mcp.sh`~~ (used fake images)
- ~~`scripts/integrate_mcp_code.sh`~~ (wrong assumptions)
- ~~`MCP_SETUP_GUIDE.md`~~ (generic/wrong info)
- ~~`MCP_SETUP_SUMMARY.md`~~ (outdated)

✅ New correct files:
- `scripts/setup_klavis_mcp.sh` (real Klavis setup)
- `KLAVIS_MCP_QUICKSTART.md` (this file)
- `KLAVIS_MCP_GUIDE.md` (created by script)

---

## Summary

**Old Scripts**: ❌ Deleted (used fake Docker images)

**New Script**: ✅ `setup_klavis_mcp.sh` (uses real Klavis images)

**Services**: Reddit, Gmail, Notion (with option to add 50+ more)

**Documentation**: Complete guide created automatically

**Time**: 5-10 minutes to setup

---

## Next Steps

1. **Run the script**:
   ```bash
   ./scripts/setup_klavis_mcp.sh
   ```

2. **Check services**:
   ```bash
   docker ps | grep mcp
   ```

3. **Read the guide**:
   ```bash
   cat KLAVIS_MCP_GUIDE.md
   ```

4. **Install client**:
   ```bash
   pip install klavis
   ```

5. **Start integrating** with your AI agents!

---

**Ready to go!** 🚀

Run: `./scripts/setup_klavis_mcp.sh`
