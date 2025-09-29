# AI Agent Playground 🚀

A complete local AI agent playground for learning and experimentation. No API keys, no internet required after setup!

## Quick Start

1. **Linux (Ubuntu/Debian/Zorin recommended)**
   - Run: `chmod +x setup.sh && ./setup.sh`
   - The script auto-installs Docker/Compose if missing, builds containers, runs health checks, and prints a summary.
2. **Windows (via WSL) or non-apt distros**
   - Install Docker Desktop (enable WSL2 integration) or install Docker manually for your distro.
   - In your shell, run: `docker compose up -d` then open http://localhost:8501
3. **Access**: Open http://localhost:8501

The Streamlit UI includes multiple agents (General Chat, RAG Assistant, Coder) and supports uploading pdf/txt/md files.

## Full documentation in `/docs/` folder:
- [High Level Architecture](docs/HLA.md)
- [Setup Guide](docs/SETUP.md)
- [Technical Design](docs/HLD.md)

## Troubleshooting

### Docker permission issues
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Docker daemon not running
- Start Docker (Desktop) or `sudo systemctl start docker` (if your OS uses systemd)

### Health checks and logs
- The setup script waits for Streamlit at `http://localhost:8501/_stcore/health` and checks Postgres.
- View logs: `docker compose logs -f | cat`
- Streamlit-only logs: `docker compose logs -f streamlit-app | cat`

### Port conflicts
- Change published ports in `docker-compose.yml` if 8501 or 5432 are taken.