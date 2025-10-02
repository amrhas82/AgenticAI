i thi# Setup Fixes - October 2025

## Issues Fixed

### 1. **Python 3.13 Compatibility**
**Problem**: Your system has Python 3.13.3, but the requirements.txt only included `psycopg2-binary` for Python < 3.13. This caused dependency installation failures.

**Solution**: 
- Added `psycopg[binary]>=3.1.0` for Python 3.13+
- Added compatibility packages: `altair>=5.0.0`, `pillow>=10.0.0`, `protobuf>=4.21.0`
- Updated all database modules to support both psycopg2 (Python < 3.13) and psycopg3 (Python 3.13+)

### 2. **Docker Container Stale Code**
**Problem**: The Docker container had cached old code with syntax errors like `value=st.sessionhealth./._state.openai_api_key`.

**Solution**: The setup.sh script now includes `--no-cache` flag when building Docker images to ensure fresh builds.

### 3. **Database Module Compatibility**
**Problem**: Three modules (`enhanced_vector_db.py`, `vector_db.py`, `api_key_manager.py`) only imported psycopg2.

**Solution**: Updated all three modules with a compatibility shim:
```python
# Try psycopg2 first (Python < 3.13), then psycopg (3.13+)
try:
    import psycopg2
    _HAVE_PSYCOPG = True
    _PSYCOPG_VERSION = 2
except Exception:
    try:
        import psycopg as psycopg2  # Use psycopg3 with psycopg2 compatible API
        _HAVE_PSYCOPG = True
        _PSYCOPG_VERSION = 3
    except Exception:
        psycopg2 = None
        _HAVE_PSYCOPG = False
        _PSYCOPG_VERSION = 0
```

## Native vs Docker Setup Differences

### **Native Setup (Option 1)**
- **What it does**: Installs Python packages directly on your host system
- **Requirements**: 
  - Python 3.8+ (you have 3.13.3 ✅)
  - Ollama installed locally
  - PostgreSQL client (optional)
- **Pros**:
  - Faster startup
  - Easier debugging
  - Direct access to files
- **Cons**:
  - Dependency conflicts with system packages
  - Requires compatible Python version
  - Manual management of services

### **Docker Setup (Option 2)**
- **What it does**: Runs everything in isolated containers
- **Components**:
  - PostgreSQL container with pgvector extension
  - Streamlit app container (Python 3.11)
  - Shared network between containers
- **Pros**:
  - Isolated environment (no system conflicts)
  - Consistent across all systems
  - PostgreSQL with pgvector included
  - Automatic service management
- **Cons**:
  - Slower startup (container initialization)
  - Requires Docker/Docker Desktop
  - More resource usage

### **GHCR (GitHub Container Registry)**
The project does NOT currently use GHCR. All images are built locally from the Dockerfile.

## How to Use the Fixes

### For Native Setup:
```bash
# Install/upgrade packages with new requirements
python3 -m pip install --user --upgrade -r requirements.txt

# Run the app
./menu.sh
# Then select option 1 (Quick Setup Native)
```

### For Docker Setup:
```bash
# Stop existing containers
docker compose down

# Rebuild with no cache (ensures fresh code)
docker compose build --no-cache

# Start services
docker compose up -d

# Or use the menu
./menu.sh
# Then select option 2 (Docker Setup)
```

## Testing Your Setup

### 1. **Check Python Dependencies**:
```bash
python3 -m pip list | grep -E "streamlit|psycopg|ollama"
```

Expected output (Python 3.13):
```
ollama                    0.1.7
psycopg                   3.1.x
psycopg-binary            3.1.x
streamlit                 1.40.x
```

### 2. **Test Docker Build**:
```bash
docker compose build --no-cache streamlit-app
docker compose up streamlit-app
```

Access: http://localhost:8501

### 3. **Health Check**:
```bash
./menu.sh
# Select option 3 (Health Check)
```

## Current Status

### What's Working Now ✅
- Python 3.13 compatibility with psycopg3
- Docker builds use fresh code (no cache)
- Database modules support both psycopg2 and psycopg3
- Streamlit dependencies properly specified

### Remaining Streamlit Issues (if any)
If you still see Streamlit errors after these fixes:

1. **Native Setup**: 
   ```bash
   python3 -m pip uninstall streamlit -y
   python3 -m pip install --user streamlit==1.40.0
   ```

2. **Docker Setup**:
   ```bash
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```

3. **Check logs**:
   ```bash
   # Native
   ./menu.sh -> Option 7 (View Logs)
   
   # Docker
   docker compose logs -f streamlit-app
   ```

## Recommendations

### For Your Environment (Python 3.13.3)
**Use Docker Setup** because:
- Your Python 3.13 is bleeding edge
- Docker container uses Python 3.11 (more stable)
- Includes PostgreSQL with pgvector
- No conflicts with your system packages

### If You Prefer Native
1. Consider using `pyenv` to install Python 3.11:
   ```bash
   curl https://pyenv.run | bash
   pyenv install 3.11.6
   pyenv local 3.11.6
   ```

2. Or use a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

## Next Steps

1. **Try Docker Setup First** (recommended):
   ```bash
   ./menu.sh
   # Select option 2
   ```

2. **If Docker works**, stick with it for consistency

3. **If you need Native**:
   ```bash
   # Create virtual environment
   python3 -m venv venv
   source venv/bin/activate
   pip install --upgrade pip
   pip install -r requirements.txt
   
   # Run native setup
   ./menu.sh
   # Select option 1
   ```

## Support

If you encounter issues:
1. Check logs in `./logs/` directory
2. Run troubleshooting: `./menu.sh` -> Option 10
3. Verify dependencies: `python3 -m pip list`
4. Check Docker: `docker info` and `docker compose version`
