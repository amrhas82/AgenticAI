#!/bin/bash

set -euo pipefail

echo "🚀 Setting up AI Agent Playground..."

# -------- Self-diagnosing helpers --------
SUMMARY=""
FAIL_COUNT=0

record_ok() {
    local msg="$1"
    SUMMARY+=$'\n'"✅ ${msg}"
}

record_warn() {
    local msg="$1"
    SUMMARY+=$'\n'"⚠️  ${msg}"
}

record_fail() {
    local msg="$1"
    SUMMARY+=$'\n'"❌ ${msg}"
    FAIL_COUNT=$((FAIL_COUNT+1))
}

wait_for_http() {
    # wait_for_http URL TIMEOUT_SECS
    local url="$1"
    local timeout="${2:-60}"
    local i=0
    while (( i < timeout )); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

check_postgres_ready() {
    # Uses host's psql if available
    local host="${1:-localhost}"
    local port="${2:-5432}"
    local db="${3:-ai_playground}"
    local user="${4:-ai_user}"
    local password="${5:-ai_password}"

    if ! have_cmd psql; then
        return 2
    fi

    local i=0
    local timeout=60
    while (( i < timeout )); do
        if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$db" -c 'select 1' >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    return 1
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_sudo() {
    if [[ $(id -u) -ne 0 ]] && ! have_cmd sudo; then
        echo "❌ This script needs administrative privileges but 'sudo' is not available."
        exit 1
    fi
}

apt_install() {
    sudo apt-get update -y
    sudo apt-get install -y "$@"
}

install_docker_apt() {
    echo "🔧 Installing Docker Engine (Ubuntu/Zorin)..."
    # Remove potentially conflicting packages
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    apt_install ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Derive codename compatible with Ubuntu repo (Zorin is Ubuntu-based)
    . /etc/os-release
    UBUNTU_CODENAME_COMPUTED="${UBUNTU_CODENAME:-${VERSION_CODENAME:-focal}}"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME_COMPUTED} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    apt_install apt-transport-https
    sudo apt-get update -y
    # Install Docker + Compose plugin
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "✅ Docker installed. Enabling and starting service..."
    sudo systemctl enable --now docker || true
}

install_postgres_client_apt() {
    echo "🔧 Installing PostgreSQL client (psql)..."
    apt_install postgresql-client || true
}

ensure_docker() {
    if ! have_cmd docker; then
        # Detect apt-based systems (Ubuntu/Zorin/Debian)
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID:-}" == "zorin" ]]; then
                require_sudo
                install_docker_apt
            else
                echo "❌ Unsupported distro for automated Docker install (ID=${ID:-unknown}). Install Docker manually."
                exit 1
            fi
        else
            echo "❌ Cannot detect OS. Install Docker manually."
            exit 1
        fi
    fi

    # Ensure daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo "🔁 Starting Docker daemon..."
        require_sudo || true
        sudo systemctl start docker || true
        sleep 2
    fi

    # Fallback to rootless docker if systemd isn't available or daemon still down
    if ! docker info >/dev/null 2>&1; then
        echo "🪄 Trying rootless Docker fallback..."
        if have_cmd dockerd-rootless-setuptool.sh; then
            export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            mkdir -p "$XDG_RUNTIME_DIR"
            dockerd-rootless-setuptool.sh install -f || true
            nohup dockerd-rootless.sh >/tmp/dockerd-rootless.log 2>&1 &
            export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
            # If using rootless, never prefix with sudo
            DOCKER_PREFIX=""
            sleep 3
        fi
    fi

    # Final verification
    if ! docker info >/dev/null 2>&1; then
        return 1
    fi
}

# Install Docker if missing and ensure daemon
if ensure_docker; then
    record_ok "Docker available and daemon reachable"
else
    record_fail "Docker setup failed"
fi

# Optionally install psql for convenience on apt systems
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID:-}" == "zorin" ]]; then
        if install_postgres_client_apt; then
            record_ok "PostgreSQL client installed"
        else
            record_warn "PostgreSQL client install skipped/failed"
        fi
    fi
fi

# Handle docker group membership; fall back to sudo when needed
DOCKER_PREFIX=""
if ! groups "$USER" | grep -q '\bdocker\b'; then
    echo "⚠️  Adding user '$USER' to 'docker' group (to avoid using sudo)..."
    require_sudo || true
    if sudo usermod -aG docker "$USER"; then
        record_ok "User added to docker group (re-login needed)"
    else
        record_warn "Could not add user to docker group"
    fi
    echo "ℹ️  You'll need to log out/in for group changes to apply. Continuing this run with sudo..."
    DOCKER_PREFIX="sudo "
fi

# Verify Docker works
${DOCKER_PREFIX}docker --version | sed 's/^/✅ /'
if ${DOCKER_PREFIX}docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="${DOCKER_PREFIX}docker compose"
elif have_cmd docker-compose; then
    COMPOSE_CMD="${DOCKER_PREFIX}docker-compose"
else
    echo "❌ Docker Compose not available even after install."
    echo "   Ensure 'docker-compose-plugin' is installed or install 'docker-compose' binary."
    exit 1
fi

# Check if Ollama is installed (optional local runtime)
if ! have_cmd ollama; then
    echo "❌ Ollama not found. Installing Ollama..."
    if curl -fsSL https://ollama.ai/install.sh | sh; then
        record_ok "Ollama installed"
    else
        record_warn "Ollama install failed or skipped"
    fi
else
    record_ok "Ollama already installed"
fi

# Create .env with sensible defaults if missing (used for local dev)
if [ ! -f .env ]; then
    echo "📝 Creating default .env file..."
    cat > .env << 'EOF'
# Local development defaults (Docker Compose sets its own env for containers)
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://localhost:8080
EOF
fi

# Build and start containers
echo "🐳 Building and starting Docker containers..."
# Ensure DOCKER_HOST is propagated to compose if set
if [[ -n "${DOCKER_HOST:-}" ]]; then
    export DOCKER_HOST
fi
if ${COMPOSE_CMD} down; then
    record_ok "Compose: stopped any running services"
else
    record_warn "Compose down encountered issues"
fi

if ${COMPOSE_CMD} build --no-cache; then
    record_ok "Compose: images built"
else
    record_fail "Compose build failed"
fi

if ${COMPOSE_CMD} up -d; then
    record_ok "Compose: services started"
else
    record_fail "Compose up failed"
fi

# Health checks
echo "🧪 Running health checks..."

# Check postgres container healthy by trying TCP via psql (host port)
if check_postgres_ready localhost 5432 ai_playground ai_user ai_password; then
    record_ok "Postgres responds on localhost:5432"
else
    record_warn "Postgres not reachable via psql from host (may still be starting)"
fi

# Check streamlit endpoint inside container healthcheck and from host
if wait_for_http "http://localhost:8501/_stcore/health" 90; then
    record_ok "Streamlit health endpoint responded"
else
    record_fail "Streamlit did not respond on http://localhost:8501"
fi

echo "\n=============================="
echo "Setup summary"
echo "=============================="
echo "$SUMMARY"

if (( FAIL_COUNT > 0 )); then
    echo "\nSome issues were detected (failures: $FAIL_COUNT)."
    echo "View logs: ${COMPOSE_CMD} logs --tail=200 | cat"
    exit 1
else
    echo "\n✅ Setup complete!"
    echo "🌐 Streamlit app: http://localhost:8501"
    echo "🗄️  PostgreSQL (in Docker): localhost:5432"
    echo "\n📋 Useful commands:"
    echo "   View logs: ${COMPOSE_CMD} logs -f streamlit-app | cat"
    echo "   Stop services: ${COMPOSE_CMD} down"
    echo "   Restart: ${COMPOSE_CMD} restart"
fi