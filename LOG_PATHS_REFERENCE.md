# Log Paths & Naming Reference Guide

**Quick reference for all log files in the AI Agent Playground**

---

## 📁 Log Directory Structure

```
./logs/                                  # Main log directory
├── menu_20251002_143022.log            # Menu script operations (timestamped)
├── ollama.log                          # Ollama server output
├── ollama.pid                          # Ollama process ID
├── streamlit.log                       # Streamlit application output
├── streamlit.pid                       # Streamlit process ID
├── pip_install.log                     # Python package installations
├── docker_setup.log                    # Docker setup operations
├── docker_restart.log                  # Docker restart operations
├── health_check_20251002_143022.log    # Health check results (timestamped)
├── model_pull_20251002_143022.log      # Model download logs (timestamped)
├── system_info.log                     # System information dump
└── troubleshooting_20251002_143022.log # Troubleshooting diagnostics (timestamped)
```

---

## 🔍 Log File Details

### Service Logs

#### Streamlit Application
- **Path:** `./logs/streamlit.log`
- **Purpose:** Streamlit web app console output, errors, and debug info
- **Created by:** `menu.sh` (Option 4), `run_local.sh`
- **PID File:** `./logs/streamlit.pid`
- **Rotation:** Manual (overwrites on service restart)

#### Ollama Server
- **Path:** `./logs/ollama.log`
- **Purpose:** Ollama LLM server output, API requests, errors
- **Created by:** `menu.sh` (Option 4), `run_local.sh`
- **PID File:** `./logs/ollama.pid`
- **Rotation:** Manual (overwrites on service restart)

---

### Setup & Installation Logs

#### Python Package Installation
- **Path:** `./logs/pip_install.log`
- **Purpose:** pip install output, package versions, errors
- **Created by:** `menu.sh` (Option 1), `run_local.sh`
- **Rotation:** Overwrites on each setup

#### Docker Setup
- **Path:** `./logs/docker_setup.log`
- **Purpose:** Docker installation and configuration output
- **Created by:** `menu.sh` (Option 2)
- **Rotation:** Overwrites on each setup

#### Docker Restart
- **Path:** `./logs/docker_restart.log`
- **Purpose:** Docker container restart operations
- **Created by:** `menu.sh` (Option 6)
- **Rotation:** Overwrites on each restart

---

### Diagnostic Logs (Timestamped)

#### Health Check
- **Path:** `./logs/health_check_YYYYMMDD_HHMMSS.log`
- **Purpose:** System health status, service availability checks
- **Created by:** `menu.sh` (Option 3)
- **Example:** `health_check_20251002_143022.log`
- **Rotation:** New file for each run (timestamp prevents overwrites)

#### Troubleshooting
- **Path:** `./logs/troubleshooting_YYYYMMDD_HHMMSS.log`
- **Purpose:** Comprehensive diagnostics, error analysis, recommendations
- **Created by:** `menu.sh` (Option 10)
- **Example:** `troubleshooting_20251002_143022.log`
- **Rotation:** New file for each run

#### Model Pull
- **Path:** `./logs/model_pull_YYYYMMDD_HHMMSS.log`
- **Purpose:** Ollama model download progress and errors
- **Created by:** `menu.sh` (Option 8)
- **Example:** `model_pull_20251002_143022.log`
- **Rotation:** New file for each model download

#### Menu Operations
- **Path:** `./logs/menu_YYYYMMDD_HHMMSS.log`
- **Purpose:** All menu script operations and selections
- **Created by:** `menu.sh` (automatically)
- **Example:** `menu_20251002_143022.log`
- **Rotation:** New file for each menu session

---

### System Information

#### System Info Dump
- **Path:** `./logs/system_info.log`
- **Purpose:** Installation paths, versions, service status
- **Created by:** `menu.sh` (Option 9)
- **Rotation:** Overwrites on each info dump

---

## 🎯 Quick Access Commands

### View Logs

```bash
# Streamlit logs
tail -f ./logs/streamlit.log

# Ollama logs
tail -f ./logs/ollama.log

# Recent health check
ls -t ./logs/health_check_*.log | head -1 | xargs cat

# Recent troubleshooting
ls -t ./logs/troubleshooting_*.log | head -1 | xargs cat

# All recent logs
tail -f ./logs/*.log
```

### Check Service Status

```bash
# Check if Streamlit is running
cat ./logs/streamlit.pid 2>/dev/null && echo "Running" || echo "Not running"

# Check if Ollama is running
cat ./logs/ollama.pid 2>/dev/null && echo "Running" || echo "Not running"
```

### Clean Up Old Logs

```bash
# Remove old timestamped logs (keep last 10 of each)
cd logs/
ls -t health_check_*.log | tail -n +11 | xargs rm -f 2>/dev/null
ls -t troubleshooting_*.log | tail -n +11 | xargs rm -f 2>/dev/null
ls -t model_pull_*.log | tail -n +11 | xargs rm -f 2>/dev/null
ls -t menu_*.log | tail -n +11 | xargs rm -f 2>/dev/null
```

---

## 📋 Log Format Examples

### Streamlit Log
```
2025-10-02 14:30:22.123 INFO    streamlit.server.server: Starting Streamlit server
2025-10-02 14:30:22.456 INFO    streamlit.server.server: Server started on port 8501
```

### Ollama Log
```
[GIN] 2025/10/02 - 14:30:23 | 200 |   123.456ms |  127.0.0.1 | POST "/api/generate"
time=2025-10-02T14:30:23.789+00:00 level=INFO msg="model loaded" model=llama2
```

### Menu Log
```
[2025-10-02 14:30:24] Starting Quick Setup (Native Mode - No Docker)...
[2025-10-02 14:30:25] [INFO] Installation paths will be logged to: ./logs/menu_20251002_143024.log
[2025-10-02 14:30:26] [SUCCESS] Python found at: /usr/bin/python3
```

---

## ⚙️ Configuration

### Log Directory
Set in `menu.sh`:
```bash
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
```

Set in `run_local.sh`:
```bash
mkdir -p logs
```

### Customize Log Location
To change the log directory location, edit the `LOG_DIR` variable in `menu.sh`:

```bash
# Default
LOG_DIR="./logs"

# Custom location
LOG_DIR="/var/log/ai-playground"
```

---

## 🔔 Important Notes

1. **PID Files:** Automatically cleaned up when services stop gracefully
2. **Timestamped Logs:** Accumulate over time - manual cleanup recommended
3. **Service Logs:** Overwrite on restart - backup if needed
4. **Log Directory:** Created automatically if missing
5. **Permissions:** Ensure write access to log directory

---

## 📊 Log File Summary

| Log File | Service | Type | Rotation |
|----------|---------|------|----------|
| `streamlit.log` | Streamlit | Service | Overwrite |
| `ollama.log` | Ollama | Service | Overwrite |
| `pip_install.log` | Setup | Setup | Overwrite |
| `docker_setup.log` | Docker | Setup | Overwrite |
| `docker_restart.log` | Docker | Operation | Overwrite |
| `health_check_*.log` | Diagnostic | Check | Timestamped |
| `troubleshooting_*.log` | Diagnostic | Debug | Timestamped |
| `model_pull_*.log` | Ollama | Download | Timestamped |
| `menu_*.log` | Menu | Operation | Timestamped |
| `system_info.log` | System | Info | Overwrite |

---

## ✅ Verification

All log paths have been verified for:
- ✅ Correct directory (`./logs/`)
- ✅ Descriptive names (service/function clearly identified)
- ✅ Consistent naming across scripts
- ✅ Proper separation (service vs operation vs diagnostic)
- ✅ Timestamp usage where appropriate

**Status: PRODUCTION READY**

---

*Last Updated: 2025-10-02*  
*Generated from codebase review*
