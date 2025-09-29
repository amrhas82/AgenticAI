#!/bin/bash

set -euo pipefail

echo "🚀 Setting up AI Agent Playground..."

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
        require_sudo
        sudo systemctl start docker || true
        sleep 2
    fi
}

# Install Docker if missing and ensure daemon
ensure_docker

# Optionally install psql for convenience on apt systems
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID:-}" == "zorin" ]]; then
        install_postgres_client_apt || true
    fi
fi

# Handle docker group membership; fall back to sudo when needed
DOCKER_PREFIX=""
if ! groups "$USER" | grep -q '\bdocker\b'; then
    echo "⚠️  Adding user '$USER' to 'docker' group (to avoid using sudo)..."
    require_sudo
    sudo usermod -aG docker "$USER" || true
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
    curl -fsSL https://ollama.ai/install.sh | sh || true
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
${COMPOSE_CMD} down || true
${COMPOSE_CMD} build --no-cache

if ${COMPOSE_CMD} up -d; then
    echo "✅ Setup complete!"
    echo ""
    echo "🌐 Streamlit app: http://localhost:8501"
    echo "🗄️  PostgreSQL (in Docker): localhost:5432"
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs: ${COMPOSE_CMD} logs -f streamlit-app"
    echo "   Stop services: ${COMPOSE_CMD} down"
    echo "   Restart: ${COMPOSE_CMD} restart"
else
    echo "❌ Docker Compose failed. Check the errors above."
    exit 1
fi