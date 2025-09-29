# AI Agent Playground 🚀

A complete local AI agent playground for learning and experimentation. No API keys, no internet required after setup!

## Quick Start

1. **Linux (Ubuntu/Debian/Zorin recommended)**
   - Run: `chmod +x setup.sh && ./setup.sh`
   - The script auto-installs Docker/Compose if missing, builds containers, runs health checks, and prints a step-wise summary of what succeeded/failed.
2. **Windows 10/11 (Docker Desktop + WSL2)**
   - Ensure Docker Desktop is running and WSL2 integration is enabled for your distro.
   - Run: `chmod +x setup-win.sh && ./setup-win.sh`
   - Alternatively, inside Ubuntu WSL you may use `./setup.sh`.
3. **Other Linux distros**
   - Install Docker + Compose for your distro, then run: `docker compose up -d`
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
- Start Docker Desktop (Windows/macOS) or `sudo systemctl start docker` (Linux with systemd)

### Permission denied to /var/run/docker.sock
- The setup scripts detect this and retry with `sudo` when possible.
- To fix permanently: add your user to the `docker` group (see above), then log out/in.

### Health checks and logs
- The setup scripts wait for Streamlit at `http://localhost:8501/_stcore/health` and check Postgres.
- Both scripts print a step-wise summary at the end, including any failures and a hint to view logs.
- View logs: `docker compose logs -f | cat`
- Streamlit-only logs: `docker compose logs -f streamlit-app | cat`

### Port conflicts
- Change published ports in `docker-compose.yml` if 8501 or 5432 are taken.