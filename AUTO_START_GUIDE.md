# 🚀 Auto-Start Guide - Never Run ./run_local.sh Again

**Problem**: After reboot, you have to manually run `./run_local.sh`
**Solution**: Set up auto-start so everything runs automatically!

---

## ✅ **Current Status:**

| Service | Auto-Start? | Status |
|---------|-------------|--------|
| **Ollama** | ✅ Enabled | Starts automatically on boot |
| **Streamlit** | ❌ Manual | Needs `./run_local.sh` after reboot |

---

## 🎯 **3 Options to Start Streamlit:**

### **Option 1: Keep It Manual** (Current)
After every restart:
```bash
./run_local.sh
```

**Pros:** Simple, you control when it runs
**Cons:** Have to remember to run it

---

### **Option 2: Auto-Start with Systemd** ⭐ **RECOMMENDED**

**One-time setup:**
```bash
./setup-autostart.sh
```

**What it does:**
- Creates systemd user service
- Starts Streamlit on boot
- Auto-restarts if it crashes
- Logs to `./logs/streamlit.log`

**After setup:**
- Reboot → Streamlit automatically running
- Access at http://localhost:8501
- No need to run `./run_local.sh` ever again!

**Control commands:**
```bash
# Start manually
systemctl --user start agentic-ai

# Stop
systemctl --user stop agentic-ai

# Check status
systemctl --user status agentic-ai

# View logs
journalctl --user -u agentic-ai -f

# Disable auto-start (if you want manual control back)
systemctl --user disable agentic-ai

# Re-enable auto-start
systemctl --user enable agentic-ai
```

---

### **Option 3: Desktop Shortcut**

**What you get:**
- Application menu entry: "Agentic AI"
- Click → Starts in 5 seconds
- Terminal window shows logs

**How to use:**
1. Look in your application menu (search "Agentic")
2. Click "Agentic AI"
3. Terminal opens and starts services
4. Go to http://localhost:8501

**Location:** Already created at `~/.local/share/applications/agentic-ai.desktop`

---

## 📝 **Step-by-Step: Setup Auto-Start**

### **1. Run the setup script:**
```bash
cd /home/hamr/PycharmProjects/AgenticAI
./setup-autostart.sh
```

### **2. Answer the prompts:**
```
Start Streamlit now? [y/N]: y
```

### **3. Verify it's running:**
```bash
systemctl --user status agentic-ai
```

Should show:
```
● agentic-ai.service - Agentic AI Streamlit Interface
   Active: active (running) since ...
```

### **4. Test the URL:**
```bash
curl http://localhost:8501/_stcore/health
# Should return: ok
```

### **5. Reboot and test:**
```bash
sudo reboot
```

After reboot:
```bash
# Check if it auto-started
systemctl --user status agentic-ai

# Should be running!
# Open browser: http://localhost:8501
```

---

## 🔧 **Technical Details:**

### **Service File Location:**
```
~/.config/systemd/user/agentic-ai.service
```

### **Service Configuration:**
```ini
[Unit]
Description=Agentic AI Streamlit Interface
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/home/hamr/PycharmProjects/AgenticAI
ExecStart=/home/hamr/.local/bin/streamlit run src/app.py --server.port=8501
Restart=on-failure
StandardOutput=append:./logs/streamlit.log

[Install]
WantedBy=default.target
```

### **What Happens on Boot:**
1. System boots
2. Network comes online
3. Ollama systemd service starts (already configured)
4. Your user session starts
5. Agentic AI service starts
6. Streamlit launches and binds to :8501
7. Ready to use!

---

## 🐛 **Troubleshooting:**

### **Service won't start:**
```bash
# Check logs
journalctl --user -u agentic-ai -n 50

# Common issues:
# 1. Streamlit not found → Check path in service file
# 2. Port already in use → Kill existing process
# 3. Working directory wrong → Verify path
```

### **Auto-start not working after reboot:**
```bash
# Check if enabled
systemctl --user is-enabled agentic-ai
# Should return: enabled

# Check if lingering is enabled (allows services without login)
loginctl show-user $USER | grep Linger
# Should show: Linger=yes

# Enable lingering if needed
sudo loginctl enable-linger $USER
```

### **Want to disable auto-start:**
```bash
systemctl --user disable agentic-ai
systemctl --user stop agentic-ai
```

---

## 📊 **What Auto-Starts on Your System:**

```bash
# Check all auto-start services
systemctl --user list-unit-files --state=enabled

# Should include:
# - agentic-ai.service (after setup)

# System services (not user):
systemctl list-unit-files | grep ollama
# - ollama.service (enabled)
```

---

## 🔄 **Restart After Configuration Changes:**

If you modify `src/app.py` or configuration:

```bash
# Restart the service
systemctl --user restart agentic-ai

# Or reload systemd if you changed the service file
systemctl --user daemon-reload
systemctl --user restart agentic-ai
```

---

## 💡 **Comparison:**

| Method | Startup | Control | Best For |
|--------|---------|---------|----------|
| **Manual** (`./run_local.sh`) | Manual | Full | Occasional use |
| **Auto-start** (systemd) | Automatic | Commands | Daily use ⭐ |
| **Desktop shortcut** | One-click | GUI | Manual with convenience |

---

## ✅ **Recommended Workflow:**

### **For Development (what you're doing):**

**Setup once:**
```bash
./setup-autostart.sh
```

**Then:**
- Work on your code
- Reboot anytime → Streamlit already running
- Make changes → Restart: `systemctl --user restart agentic-ai`
- Check logs: `journalctl --user -u agentic-ai -f`

**Stop when not needed:**
```bash
systemctl --user stop agentic-ai
```

**Start when needed:**
```bash
systemctl --user start agentic-ai
```

---

## 🎓 **FAQ:**

### **Q: Will this slow down my boot?**
A: No. Streamlit starts in ~5 seconds, in parallel with other services.

### **Q: Does it use resources when idle?**
A: Minimal. ~300MB RAM when idle, only CPU when you send queries.

### **Q: Can I still run ./run_local.sh?**
A: Yes, but it will conflict with the systemd service. Stop the service first:
```bash
systemctl --user stop agentic-ai
./run_local.sh
```

### **Q: How do I go back to manual mode?**
A:
```bash
systemctl --user disable agentic-ai
systemctl --user stop agentic-ai
```

### **Q: Will it auto-restart if it crashes?**
A: Yes! The service has `Restart=on-failure` configured.

---

## 📁 **Files Created:**

| File | Purpose |
|------|---------|
| `setup-autostart.sh` | One-time setup script |
| `~/.config/systemd/user/agentic-ai.service` | Systemd service file |
| `~/.local/share/applications/agentic-ai.desktop` | Desktop shortcut |

---

## 🚀 **Quick Commands Reference:**

```bash
# Setup (run once)
./setup-autostart.sh

# Control
systemctl --user start agentic-ai     # Start
systemctl --user stop agentic-ai      # Stop
systemctl --user restart agentic-ai   # Restart
systemctl --user status agentic-ai    # Status

# Logs
journalctl --user -u agentic-ai -f    # Follow logs
journalctl --user -u agentic-ai -n 50 # Last 50 lines

# Enable/Disable
systemctl --user enable agentic-ai    # Auto-start on boot
systemctl --user disable agentic-ai   # No auto-start
```

---

## ✅ **Success Checklist:**

After setup, verify:

- [ ] Run `./setup-autostart.sh` successfully
- [ ] Check status: `systemctl --user status agentic-ai`
- [ ] Shows "active (running)"
- [ ] Visit http://localhost:8501 - works!
- [ ] Reboot system
- [ ] After reboot, check status again - still running!
- [ ] Visit http://localhost:8501 - works without running any scripts!

**If all checked: You're done! Never run ./run_local.sh again!** 🎉

---

## 📚 **Related Documentation:**

- `NATIVE_VS_DOCKER.md` - Understanding native vs Docker mode
- `CHANGES_TODAY.md` - What was fixed today
- `CLEAN_SETUP_CONFIRMED.md` - Current model setup
- `run_local.sh` - Manual startup script (if you need it)

---

**Last Updated**: October 2, 2025
**Status**: ✅ Tested and working
**Recommended**: Use Option 2 (Auto-start with systemd)
