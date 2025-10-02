# 🚀 AI Agent Playground - Simple Start Guide

## TL;DR - Get Started in 2 Minutes

```bash
# 1. Run the menu
./menu.sh

# 2. Choose Option 1 (Quick Setup)
# 3. Choose Option 8 (Install a model - pick llama3.2:1b)
# 4. Choose Option 4 (Start Services)
# 5. Open browser: http://localhost:8501
```

That's it! You now have a local AI chat interface.

---

## Why This Guide Exists

You asked great questions about getting this local AI interface working simply and reliably. This guide answers them all.

### Your Questions Answered:

**Q1: Why isn't there a log file generated after install or health check?**
- **A**: Fixed! All scripts now create logs in `./logs/` directory with full paths and installation details.

**Q2: Where are all the images and Docker running? Logs should mention paths.**
- **A**: All paths are now logged:
  - Logs: `./logs/`
  - Data: `./data/`
  - Models: `~/.ollama/models/`
  - Run `./menu.sh` → Option 9 to see all paths

**Q3: If I restart or hibernate my laptop, do I need to start Docker again?**
- **A**: Yes for manual mode, but you can auto-start services. See [STARTUP_GUIDE.md](docs/STARTUP_GUIDE.md) for systemd setup.

**Q4: Why don't we create a menu script?**
- **A**: Done! `./menu.sh` gives you all options in one place.

**Q5: Why are we still having problems?**
- **A**: We've simplified everything. You DON'T need Docker for basic chat with local LLMs. Use native mode instead!

---

## Three Ways to Run

### Method 1: Interactive Menu (Recommended)

```bash
./menu.sh
```

**Options include:**
1. Quick Setup (Native - No Docker)
2. Docker Setup (Full)
3. Health Check
4. Start Services (Native Mode)
5. Stop All Services
6. Restart Docker Containers
7. View Logs
8. Install/Pull Ollama Models
9. System Information
10. Run Troubleshooting

### Method 2: One-Command Start

```bash
./run_local.sh
```

Starts everything automatically in native mode.

### Method 3: Manual (Understanding What Happens)

```bash
# Start Ollama
ollama serve &

# Install a model (first time only)
ollama pull llama3.2:1b

# Start the UI
streamlit run src/app.py
```

---

## What You Need

### Minimum Requirements

1. **Python 3.8+** (you probably already have this)
2. **Ollama** (we'll install it for you)
3. **A small model** (1-3GB, we'll help you pick one)

### You DON'T Need

- ❌ Docker (unless you want the full setup)
- ❌ GPU (CPU works fine for small models)
- ❌ Lots of RAM (8GB is enough for small models)
- ❌ OpenAI API key (this is local-only)

---

## First Time Setup

### Step 1: Install Ollama (if not installed)

```bash
./menu.sh
# Choose Option 1: Quick Setup
```

Or manually:
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Step 2: Get a Model

```bash
./menu.sh
# Choose Option 8: Install/Pull Ollama Models
# Pick option 2: llama3.2:1b (recommended for testing)
```

**Model Recommendations:**

| Model | Size | Speed | Use Case |
|-------|------|-------|----------|
| `llama3.2:1b` | ~1GB | Very Fast | Testing, quick responses |
| `llama3.2` (3B) | ~2GB | Fast | Balanced performance |
| `qwen2.5-coder:1.5b` | ~1GB | Very Fast | Code-focused tasks |
| `phi3.5` | ~2GB | Fast | General purpose |

### Step 3: Start the Services

```bash
./menu.sh
# Choose Option 4: Start Services (Native Mode)
```

### Step 4: Open the UI

Open your browser to: **http://localhost:8501**

---

## After Restart/Hibernate

You have 3 options:

### Quick: Use the Menu
```bash
./menu.sh
# Choose Option 4: Start Services
```

### Quicker: Use the Run Script
```bash
./run_local.sh
```

### Auto-Start: Set Up Systemd

See the complete guide in [STARTUP_GUIDE.md](docs/STARTUP_GUIDE.md#auto-restart-after-reboot)

Quick version:
```bash
# Create Ollama service
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
User=$(whoami)
Environment="OLLAMA_HOST=0.0.0.0:11434"
ExecStart=/usr/local/bin/ollama serve
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable ollama
sudo systemctl start ollama
```

---

## Where Everything Is

Run this to see all paths:
```bash
./menu.sh
# Choose Option 9: System Information
```

Or check manually:

```
Your Project Directory: /workspace/
├── logs/                    ← All logs here
│   ├── streamlit.log       ← UI logs
│   ├── ollama.log          ← Ollama logs
│   └── *.log               ← Other logs
├── data/                    ← Your data
│   ├── documents/          ← Uploaded documents
│   ├── conversations/      ← Saved chats
│   └── uploads/            ← File uploads
├── src/                     ← App code
│   └── app.py              ← Main application
├── menu.sh                  ← Interactive menu
├── run_local.sh            ← Quick start script
└── .env                     ← Configuration

System Directories:
~/.ollama/models/           ← Downloaded models
/usr/local/bin/ollama       ← Ollama binary
```

---

## Troubleshooting

### Problem: Something isn't working

```bash
./menu.sh
# Choose Option 10: Run Troubleshooting
```

This creates a detailed report at `logs/troubleshooting_*.log`

### Problem: Want to see what's happening

```bash
# View live logs
tail -f logs/streamlit.log   # UI logs
tail -f logs/ollama.log      # Ollama logs

# Or use the menu
./menu.sh
# Choose Option 7: View Logs
```

### Problem: Port already in use

```bash
# Find what's using port 8501
lsof -i:8501

# Kill it
kill $(lsof -ti:8501)

# Or use menu
./menu.sh
# Choose Option 5: Stop All Services
```

### Problem: Health check fails

```bash
./menu.sh
# Choose Option 3: Health Check
```

This will tell you exactly what's wrong and how to fix it.

---

## Common Questions

### Do I need Docker?

**No!** Docker is optional. For basic local AI chat, native mode is simpler and faster.

Use Docker only if you:
- Want PostgreSQL database
- Need multiple users
- Want containerized deployment

### Which model should I use?

For testing: `llama3.2:1b` (smallest, fastest)
For better quality: `llama3.2` (3B version)
For coding: `qwen2.5-coder:1.5b`

### How do I switch models?

In the UI:
1. Go to sidebar
2. Find "Model Settings"
3. Select different model from dropdown

Or install new ones:
```bash
ollama pull model-name
```

### Can I use OpenAI instead of local models?

Yes! In the UI:
1. Sidebar → Choose Provider → "OpenAI"
2. Enter your API key
3. Select OpenAI model

### Where are my conversations saved?

`./data/conversations/`

View them in the UI:
- Sidebar → Navigation → "🗂️ Conversations"

---

## Performance Tips

### Speed Up Responses

1. **Use smaller models**: `llama3.2:1b` is very fast
2. **Native mode**: Faster than Docker for local use
3. **SSD**: Store models on SSD if possible

### Save Disk Space

```bash
# Remove unused models
ollama rm model-name

# See all models and their sizes
ollama list
```

---

## Next Steps

Once you're up and running:

1. **Explore Features**: Check sidebar options
2. **Upload Documents**: Use the Documents page to add files for RAG
3. **Try Different Agents**: Switch between agents in sidebar
4. **Save Conversations**: Use the save button to keep important chats
5. **Read Full Docs**: See `docs/` folder for advanced features

---

## Quick Reference Commands

```bash
# Everything through menu
./menu.sh

# Quick start
./run_local.sh

# Manual control
ollama serve &                          # Start Ollama
streamlit run src/app.py                # Start UI
ollama pull llama3.2:1b                 # Get a model

# Check status
curl http://localhost:11434/api/tags    # Ollama
curl http://localhost:8501/_stcore/health  # Streamlit

# View logs
tail -f logs/streamlit.log
tail -f logs/ollama.log

# Stop everything
./menu.sh  # Option 5
```

---

## Getting Help

1. **Run troubleshooting**: `./menu.sh` → Option 10
2. **Check logs**: `./menu.sh` → Option 7
3. **System info**: `./menu.sh` → Option 9
4. **Read docs**: `docs/STARTUP_GUIDE.md`
5. **Health check**: `./menu.sh` → Option 3

---

## Success Checklist

- [ ] Ollama installed and running
- [ ] At least one model downloaded
- [ ] Streamlit UI accessible at http://localhost:8501
- [ ] Can send a message and get a response
- [ ] Logs being created in `./logs/` directory

If all checked, you're ready to go! 🎉

---

**Focus: Simple local AI chat without complexity.**

For advanced features (RAG, agents, MCP), see the full documentation in `docs/`.
