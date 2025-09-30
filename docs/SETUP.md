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

Optional cleanup before rebuilds:
```bash
PRUNE_DOCKER=1 ./setup.sh
```
This prunes unused images/networks/volumes to avoid conflicts.

## Windows 10/11 setup (Docker Desktop + WSL2)
1) Install Docker Desktop and enable WSL2 integration for your distro
2) From repo root in WSL shell:
```bash
chmod +x setup-win.sh && ./setup-win.sh
```
Alternatively, inside Ubuntu WSL you may use `./setup.sh`.

### If `docker` is not recognized in CMD/PowerShell

- Ensure Docker Desktop is installed and running.
- Close and reopen CMD/PowerShell after install. Docker adds its CLI to PATH.
- Verify the CLI with either of the following:

```cmd
"C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe" --version
```

```powershell
& "C:\Program Files\Docker\Docker\resources\bin\docker.exe" --version
```

- If that works but `docker` still isn’t found, add the directory above to PATH and restart the terminal, or run Docker Desktop installer again to repair PATH.

Once `docker` works in CMD/PowerShell, you can run:

```powershell
docker compose ps
docker compose logs --tail 200
```

## Manual setup (any distro/Windows with Docker Desktop)
1) Install Docker + Compose for your OS
2) Optionally install Ollama on the host if you want local models
3) From the repo root:
```bash
docker compose up -d
```
Open http://localhost:8501

### Manual Docker install (Ubuntu 24.04+/25.04)

If Docker/Compose are not yet installed on Ubuntu, use the following commands. These work well on 24.04 and 25.04 and set up the daemon and group permissions.

```bash
# 1) Prerequisites (rootless-capable as well)
sudo apt-get update -y
sudo apt-get install -y uidmap slirp4netns fuse-overlayfs dbus-user-session \
  curl ca-certificates gnupg lsb-release

# 2) Install Docker (Engine + CLI + Compose plugin)
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh

# 3) Run docker without sudo (new group membership)
sudo usermod -aG docker "$USER"
newgrp docker

# 4) Start and enable the daemon
sudo systemctl enable --now docker

# 5) Verify connectivity
docker version && docker info
```

### Optional: Rootless Docker

If you prefer to run Docker without root privileges, set up rootless mode. Ensure the prerequisites above are installed first.

```bash
# Install user-level daemon and socket
dockerd-rootless-setuptool.sh install

# Start on login and start now
systemctl --user enable --now docker

# Point the client to the user socket for this shell
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock

# Verify
docker info
```

### Bring the stack up with Compose

From the repository root:

```bash
# Clean up old state (ignore errors if first run)
docker compose down -v --remove-orphans || true

# Build and start
docker compose build --pull
docker compose up -d

# Status and recent logs
docker compose ps
docker compose logs --tail=200 | cat
```

### Health checks

```bash
# Postgres inside container (service name is `postgres`)
docker compose exec -T postgres pg_isready -U postgres || true

# From host (set PGPASSWORD if required; adjust user/db as needed)
# PGPASSWORD=ai_password psql -h localhost -p 5432 -U ai_user -d ai_playground -c '\l' || true

# Streamlit
curl -fsS http://localhost:8501/ | head -n1 || true
```

### Database/vector initialization

- The file `scripts/init_db.sql` is mounted and executed automatically by the Postgres container on first run.
- If you add custom initialization or seeding scripts, run them via a one-off container, for example:

```bash
# Example pattern (adjust the command to your project)
docker compose run --rm streamlit-app bash -lc 'python scripts/your_init_script.py'
```

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

Rootless Docker / custom DOCKER_HOST:
- If you run rootless Docker, set `DOCKER_HOST` to your user socket (e.g., `unix:///run/user/1000/docker.sock`). The setup unsets an unreachable `DOCKER_HOST` and falls back to the default.

## Ollama: add and manage local models

Ensure Ollama is running (Linux: `ollama serve`; macOS/Windows: start the Ollama app). Common commands:

```bash
# Pull models
ollama pull llama3
ollama pull mistral
ollama pull qwen2.5:7b
ollama pull phi3:mini

# Coding-focused
ollama pull codellama:7b-instruct

# Embeddings (for RAG)
ollama pull nomic-embed-text

# Run interactively
ollama run llama3

# List installed
ollama list

# Remove
ollama rm <model-name>

# Create a custom model (Modelfile)
# Modelfile contents:
#   FROM llama3
#   SYSTEM You are a concise helpful assistant.
ollama create mymodel -f Modelfile
ollama run mymodel
```

App notes
- Containers reach Ollama via `OLLAMA_HOST` (defaults to host). Update `.env` if running Ollama elsewhere.
- Change embeddings via `EMBED_MODEL` in `.env` and restart compose.