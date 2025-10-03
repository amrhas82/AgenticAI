# 📚 Documentation Index

Complete guide to all documentation files in this project.

---

## 🚀 **Getting Started**

| File | Description |
|------|-------------|
| **START_HERE.md** | Main entry point - overview and quick links |
| **QUICK_START_NOW.md** | Quickest way to get running (5 minutes) |
| **README_SIMPLE.md** | Simple guide for beginners |

---

## 🔧 **Setup & Installation**

| File | Description |
|------|-------------|
| **AUTO_START_GUIDE.md** ⭐ | Never run ./run_local.sh again (auto-start setup) |
| **NATIVE_VS_DOCKER.md** | Understanding native vs Docker mode |
| **CLEAN_SETUP_CONFIRMED.md** | Current model setup (3 coding models) |
| **SETUP_FIXES_2025.md** | Recent setup improvements |
| **setup-autostart.sh** | Script to enable auto-start on boot |
| **run_local.sh** | Manual startup script (native mode) |
| **setup.sh** | Docker mode setup |
| **setup-win.sh** | Windows/WSL setup |
| **menu.sh** | Interactive menu for all operations |

---

## 📝 **Today's Changes**

| File | Description |
|------|-------------|
| **CHANGES_TODAY.md** | Complete session summary (what was fixed) |
| **COMPLETED_WORK.md** | All work completed recently |
| **FIXES_SUMMARY.md** | Summary of issues resolved |

---

## 🤖 **Models & Performance**

| File | Description |
|------|-------------|
| **CLEAN_SETUP_CONFIRMED.md** | 3 lightweight coding models setup |
| Installed Models | deepseek-coder:1.3b, qwen2.5-coder:1.5b, qwen2.5-coder:3b |

---

## 🔍 **Technical Details**

| File | Description |
|------|-------------|
| **NATIVE_VS_DOCKER.md** | Detailed comparison of deployment modes |
| **CODEBASE_REVIEW_REPORT.md** | Code architecture review |
| **LOG_PATHS_REFERENCE.md** | Where to find all logs |

---

## 🧪 **Testing & Troubleshooting**

| File | Description |
|------|-------------|
| `./logs/` | All log files (streamlit, ollama, etc.) |
| `./logs/troubleshooting_*.log` | Diagnostic reports |

---

## 📂 **Advanced Topics**

### **MCP (Model Context Protocol) Integration:**

| File | Description |
|------|-------------|
| **MCP_AND_WEB_ACCESS.md** | Can local LLMs access internet? MCP overview |
| **MCP_SELF_HOSTED_GUIDE.md** ⭐ | Self-hosted open source MCP setup (Reddit, Gmail, Notion) |
| **scripts/setup_mcp_selfhosted.sh** | Automated self-hosted MCP installation |

### **In `docs/` directory:**

| File | Topic |
|------|-------|
| **KLAVIS_MCP_QUICKSTART.md** | MCP integration guide (hosted service) |
| **AGENT_ARCHITECTURE_DIAGRAM.md** | Agent system design |
| **AI_AGENT_GUIDE.md** | Using agents effectively |
| **FEATURES.md** | All features explained |
| **INTEGRATION.md** | Integrating with other tools |

---

## 🎯 **Quick Reference**

### **Common Tasks:**

| Task | Document | Command |
|------|----------|---------|
| First time setup | QUICK_START_NOW.md | `./menu.sh` |
| Auto-start setup | AUTO_START_GUIDE.md | `./setup-autostart.sh` |
| MCP self-hosted setup | MCP_SELF_HOSTED_GUIDE.md | `./scripts/setup_mcp_selfhosted.sh` |
| Manual start | - | `./run_local.sh` |
| Check status | - | `systemctl --user status agentic-ai` |
| Install models | menu.sh → Option 8 | `ollama pull model-name` |
| View logs | - | `tail -f logs/streamlit.log` |

---

## ✅ **Recommended Reading Order:**

1. **START_HERE.md** - Get oriented
2. **QUICK_START_NOW.md** - Get running
3. **AUTO_START_GUIDE.md** - Set up auto-start
4. **NATIVE_VS_DOCKER.md** - Understand your setup
5. **CHANGES_TODAY.md** - See what was fixed

---

## 🔄 **After Reboot:**

If you set up auto-start:
- ✅ Nothing to do! Go to http://localhost:8501

If manual mode:
- Run `./run_local.sh`
- See **AUTO_START_GUIDE.md** to avoid this

---

## 📊 **Current Setup Summary:**

```
Mode: Native (no Docker)
Models: 3 coding + 1 general + 1 embedding
Auto-start: Optional (see AUTO_START_GUIDE.md)
UI: http://localhost:8501
API: http://localhost:11434
```

---

**Last Updated**: October 2, 2025
