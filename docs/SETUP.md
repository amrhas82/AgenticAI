# Complete Setup Guide

This project provides self-diagnosing setup scripts for Linux and Windows/WSL. They run in named steps, trap errors, summarize successes/failures, and hint at logs.

## Supported environments
- Ubuntu, Debian, Zorin (apt-based): automated install via `setup.sh`
- Windows 10/11 (Docker Desktop + WSL2): automated setup via `setup-win.sh`
- Other Linux distros (Fedora/CentOS/Arch): manual Docker install, then `docker compose up -d`

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

## Windows 10/11 setup (Docker Desktop + WSL2)
1) Install Docker Desktop and enable WSL2 integration for your distro
2) From repo root in WSL shell:
```bash
chmod +x setup-win.sh && ./setup-win.sh
```
Alternatively, inside Ubuntu WSL you may use `./setup.sh`.

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
- Permission denied to `/var/run/docker.sock`: scripts detect this, retry with sudo when possible, and print guidance
- View logs: `docker compose logs -f | cat`
- Streamlit health: the setup waits on `http://localhost:8501/_stcore/health`