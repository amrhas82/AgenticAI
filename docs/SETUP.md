# Complete Setup Guide

This project provides a self-diagnosing setup script for apt-based Linux (Ubuntu/Debian/Zorin). For other environments, install Docker manually and use Docker Compose.

## Supported environments
- Ubuntu, Debian, Zorin (apt-based): automated install via `setup.sh`
- Other Linux distros (Fedora/CentOS/Arch): manual Docker install, then `docker compose up -d`
- Windows 10/11: use WSL2 (Ubuntu recommended) + Docker Desktop; or run `setup.sh` inside Ubuntu WSL

## One-line setup (Ubuntu/Debian/Zorin)
```bash
chmod +x setup.sh && ./setup.sh
```

What it does:
- Installs Docker Engine and Compose plugin if missing
- Installs `psql` client for convenience
- Adds your user to the `docker` group (log out/in required to take effect)
- Builds and starts containers
- Runs health checks for Postgres and Streamlit
- Prints a summary of successes/failures with next steps

## Manual setup (any distro/Windows with Docker Desktop)
1) Install Docker + Compose for your OS
2) Optionally install Ollama on the host if you want local models
3) From the repo root:
```bash
docker compose up -d
```
Open http://localhost:8501

## Troubleshooting
- Permission denied with Docker: add user to group and start a new shell
```bash
sudo usermod -aG docker $USER
newgrp docker
```
- Docker daemon not running: start Docker Desktop or `sudo systemctl start docker`
- View logs: `docker compose logs -f | cat`
- Streamlit health: the setup waits on `http://localhost:8501/_stcore/health`