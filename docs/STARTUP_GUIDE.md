# 🚀 Quick Startup Guide

This guide answers your key questions about running the AI Agent Playground.

## Table of Contents

1. [Quick Start (Simplest Way)](#quick-start-simplest-way)
2. [Understanding Your Setup](#understanding-your-setup)
3. [Auto-Restart After Reboot](#auto-restart-after-reboot)
4. [Log Files & Locations](#log-files--locations)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start (Simplest Way)

**For a simple local AI interface, use the menu script:**

```bash
./menu.sh
```

Then select:
- **Option 1**: Quick Setup (Native - No Docker)
- **Option 4**: Start Services (Native Mode)
- **Option 8**: Install/Pull Ollama Models (if you don't have any)

**Or use the one-command runner:**

```bash
./run_local.sh
```

This will:
1. Check if Ollama is installed and running
2. Check if you have models installed
3. Start the Streamlit UI
4. Open at http://localhost:8501

---

## Understanding Your Setup

### Two Modes Available

#### 1. **Native Mode (Recommended for Getting Started)**
- Runs directly on your machine
- No Docker required
- Faster to set up
- Uses local Python and Ollama
- **Use this if you just want to chat with local LLMs**

#### 2. **Docker Mode (Advanced)**
- Runs everything in containers
- Includes PostgreSQL database
- Better for multi-user setups
- Requires Docker Desktop/Engine
- **Use this for production or complex setups**

### What Gets Installed Where?

When you run `./menu.sh` → **Option 1** (Quick Setup), here's what happens:

```
Installation Locations:
├─ Python: /usr/bin/python3 (or wherever your system Python is)
├─ Ollama: /usr/local/bin/ollama (or /usr/bin/ollama)
├─ Ollama Models: ~/.ollama/models/
├─ Project Directory: /workspace/ (your current directory)
│  ├─ logs/                    ← All log files here
│  │  ├─ ollama.log           ← Ollama service logs
│  │  ├─ streamlit.log        ← Streamlit UI logs
│  │  ├─ health_check_*.log   ← Health check reports
│  │  └─ system_info.log      ← System information
│  ├─ data/                    ← All your data here
│  │  ├─ documents/           ← Uploaded documents
│  │  ├─ conversations/       ← Saved conversations
│  │  ├─ uploads/             ← File uploads
│  │  └─ db/                  ← Local database files
│  ├─ src/                     ← Application code
│  └─ .env                     ← Configuration settings
```

---

## Auto-Restart After Reboot

### Question: Do I need to start Docker/services again after hibernating or rebooting?

**Answer: Yes, by default.** But you have options:

### Option A: Manual Start (Simplest)

After reboot/hibernate, just run:

```bash
./menu.sh
# Select option 4: Start Services (Native Mode)
```

Or:

```bash
./run_local.sh
```

### Option B: Auto-Start with Systemd (Linux)

Create systemd services to auto-start Ollama and Streamlit on boot.

#### 1. Auto-Start Ollama

```bash
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
User=YOUR_USERNAME
Environment="OLLAMA_HOST=0.0.0.0:11434"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Replace YOUR_USERNAME with your actual username
sudo sed -i "s/YOUR_USERNAME/$(whoami)/" /etc/systemd/system/ollama.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable ollama.service
sudo systemctl start ollama.service
```

#### 2. Auto-Start Streamlit AI Interface

```bash
sudo tee /etc/systemd/system/ai-playground.service > /dev/null << 'EOF'
[Unit]
Description=AI Agent Playground Streamlit UI
After=network-online.target ollama.service
Requires=ollama.service

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/workspace
Environment="PATH=/usr/local/bin:/usr/bin"
ExecStart=/usr/local/bin/streamlit run src/app.py --server.port=8501 --server.address=0.0.0.0
Restart=always
RestartSec=3
StandardOutput=append:/workspace/logs/streamlit.log
StandardError=append:/workspace/logs/streamlit.log

[Install]
WantedBy=multi-user.target
EOF

# Replace YOUR_USERNAME with your actual username
sudo sed -i "s/YOUR_USERNAME/$(whoami)/" /etc/systemd/system/ai-playground.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable ai-playground.service
sudo systemctl start ai-playground.service
```

#### Managing Systemd Services

```bash
# Check status
sudo systemctl status ollama
sudo systemctl status ai-playground

# View logs
sudo journalctl -u ollama -f
sudo journalctl -u ai-playground -f

# Stop services
sudo systemctl stop ollama
sudo systemctl stop ai-playground

# Disable auto-start
sudo systemctl disable ollama
sudo systemctl disable ai-playground
```

### Option C: Docker Auto-Start

If using Docker mode, make containers restart automatically:

```bash
# Edit docker-compose.yml and add restart policy
# (Already configured in your docker-compose.yml)

# Ensure Docker starts on boot
sudo systemctl enable docker

# Containers will now auto-start when Docker starts
```

---

## Log Files & Locations

### Where Are All The Logs?

All logs are in the `logs/` directory in your project:

```bash
cd /workspace  # Your project directory
ls -lh logs/   # List all log files

# View recent logs
tail -f logs/streamlit.log   # Streamlit UI logs
tail -f logs/ollama.log      # Ollama service logs
```

### Log Files Explained

| Log File | Purpose | When Created |
|----------|---------|--------------|
| `logs/streamlit.log` | Streamlit UI errors and info | When you start the UI |
| `logs/ollama.log` | Ollama service logs | When Ollama starts |
| `logs/health_check_*.log` | Health check results | When you run health check |
| `logs/menu_*.log` | Menu script operations | When you use menu.sh |
| `logs/system_info.log` | System information | When you check system info |
| `logs/pip_install.log` | Python package installation | During setup |
| `logs/docker_setup.log` | Docker setup logs | During Docker setup |

### Viewing Logs from Menu

```bash
./menu.sh
# Select option 7: View Logs
```

### Why Logs Are Important

Logs tell you:
- **Installation paths** - Where everything was installed
- **Errors** - What went wrong and why
- **Service status** - Whether services are running
- **Performance** - How well things are working

---

## Troubleshooting

### Problem: No Log Files Generated

**Cause**: The `logs/` directory wasn't created, or scripts didn't have write permissions.

**Solution**:
```bash
mkdir -p logs
chmod +w logs
./menu.sh  # Try again
```

### Problem: Docker Not Available

**Cause**: Docker is not installed or not running.

**Solution**:
```bash
# Check Docker status
docker info

# If not installed, use native mode instead:
./menu.sh
# Select Option 1: Quick Setup (Native - No Docker)
```

**You don't need Docker for basic usage!** Native mode works great for local AI.

### Problem: Can't Find Where Things Are Installed

**Solution**:
```bash
./menu.sh
# Select option 9: System Information
# This shows all installation paths
```

Or manually check:
```bash
which python3
which ollama
which streamlit
which docker
```

### Problem: Port 8501 Already in Use

**Cause**: Streamlit is already running, or another app is using the port.

**Solution**:
```bash
# Find what's using the port
lsof -i:8501

# Kill the process
kill $(lsof -ti:8501)

# Or use the menu
./menu.sh
# Select option 5: Stop All Services
```

### Problem: Syntax Error in app.py

If you see:
```
File "/app/src/app.py", line 154
    value=st.sessionhealth./._state.openai_api_key,
                         ^
SyntaxError: invalid syntax
```

**Cause**: File corruption or incomplete write.

**Solution**:
```bash
# The file should be correct now
# If you still see this error, check if the file was modified:
git status
git diff src/app.py

# Reset to clean version:
git checkout src/app.py
```

### Problem: Services Don't Restart After Reboot

**Cause**: No auto-start configured.

**Solution**: See [Auto-Restart After Reboot](#auto-restart-after-reboot) section above.

### Running Comprehensive Troubleshooting

```bash
./menu.sh
# Select option 10: Run Troubleshooting
```

This checks:
- System requirements
- Port availability
- Service connectivity
- File integrity
- Recent errors

---

## Summary of Key Points

1. **Simplest way to start**: `./run_local.sh`
2. **Menu for everything**: `./menu.sh`
3. **Logs location**: `./logs/` directory
4. **After reboot**: Run `./menu.sh` → option 4, or set up systemd
5. **No Docker needed**: Native mode works great for local AI
6. **Getting stuck?**: Run `./menu.sh` → option 10 (Troubleshooting)

---

## Quick Command Reference

```bash
# Start everything (easiest)
./run_local.sh

# Use menu system
./menu.sh

# Manual start
ollama serve &                    # Start Ollama
streamlit run src/app.py          # Start UI

# Check status
curl http://localhost:11434/api/tags    # Ollama API
curl http://localhost:8501/_stcore/health  # Streamlit

# View logs
tail -f logs/streamlit.log
tail -f logs/ollama.log

# Stop everything
./menu.sh  # Option 5
```

---

## Getting Help

If you're still having issues:

1. Run: `./menu.sh` → **Option 10** (Troubleshooting)
2. Check: `./logs/troubleshooting_*.log`
3. Review: `./docs/TROUBLESHOOTING.md`
4. System info: `./menu.sh` → **Option 9**

---

**Happy chatting with your local AI! 🤖**
