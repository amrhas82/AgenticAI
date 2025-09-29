#!/bin/bash

set -Euo pipefail

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

# Step tracking and robust summary printing
CURRENT_STEP="startup"

begin_step() {
    local name="$1"
    CURRENT_STEP="$name"
    printf "\n— %s —\n" "$name"
}

print_summary() {
    printf "\n==============================\n"
    printf "Setup summary\n"
    printf "==============================\n"
    printf "%s\n" "$SUMMARY"

    if (( FAIL_COUNT > 0 )); then
        printf "\nSome issues were detected (failures: %s).\n" "$FAIL_COUNT"
        if [[ -n "${COMPOSE_CMD:-}" ]]; then
            printf "View logs: %s logs --tail=200 | cat\n" "$COMPOSE_CMD"
        else
            printf "Docker Compose wasn't available; ensure Docker Desktop/Engine is running.\n"
        fi
        exit 1
    else
        printf "\n✅ Setup complete!\n"
        printf "🌐 Streamlit app: http://localhost:8501\n"
        printf "🗄️  PostgreSQL (in Docker): localhost:5432\n"
        printf "\n📋 Useful commands:\n"
        if [[ -n "${COMPOSE_CMD:-}" ]]; then
            printf "   View logs: %s logs -f streamlit-app | cat\n" "$COMPOSE_CMD"
            printf "   Stop services: %s down\n" "$COMPOSE_CMD"
            printf "   Restart: %s restart\n" "$COMPOSE_CMD"
        fi
    fi
}

handle_err() {
    local line="$1"
    local cmd="$2"
    if [[ "$cmd" == docker* || "$cmd" == *" docker "* || "$cmd" == *"docker compose"* ]]; then
        record_fail "Docker command failed in step '${CURRENT_STEP}': ${cmd}"
        record_warn "If you saw 'permission denied to /var/run/docker.sock', add your user to 'docker' group then log out/in, or re-run with sudo."
    else
        record_fail "Error in step '${CURRENT_STEP}' at line ${line}: ${cmd}"
    fi
}

trap 'handle_err "$LINENO" "$BASH_COMMAND"' ERR
trap 'print_summary' EXIT

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

detect_package_manager() {
    if have_cmd apt-get; then echo apt; return; fi
    if have_cmd dnf; then echo dnf; return; fi
    if have_cmd yum; then echo yum; return; fi
    if have_cmd zypper; then echo zypper; return; fi
    if have_cmd pacman; then echo pacman; return; fi
    if have_cmd apk; then echo apk; return; fi
    echo unknown
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

install_docker_convenience() {
    # Use Docker's official convenience script for broad distro coverage
    require_sudo
    printf "🔧 Installing Docker via get.docker.com script...\n"
    curl -fsSL https://get.docker.com | sudo sh
    printf "✅ Docker installed. Enabling and starting service...\n"
    sudo systemctl enable --now docker || true
}

install_postgres_client_any() {
    local pm
    pm=$(detect_package_manager)
    printf "🔧 Installing PostgreSQL client (psql) using %s...\n" "$pm"
    case "$pm" in
        apt)
            apt_install postgresql-client || true
            ;;
        dnf)
            sudo dnf install -y postgresql || true
            ;;
        yum)
            sudo yum install -y postgresql || true
            ;;
        zypper)
            sudo zypper --non-interactive install postgresql || true
            ;;
        pacman)
            sudo pacman -Sy --noconfirm postgresql || true
            ;;
        apk)
            sudo apk add --no-cache postgresql-client || true
            ;;
        *)
            printf "⚠️  Unknown package manager; skipping psql install.\n"
            return 1
            ;;
    esac
}

ensure_docker() {
    if ! have_cmd docker; then
        case "$(detect_package_manager)" in
            apt)
                require_sudo
                install_docker_apt
                ;;
            dnf|yum|zypper|pacman|apk)
                install_docker_convenience
                ;;
            *)
                echo "❌ Could not detect a supported package manager. Please install Docker manually."
                exit 1
                ;;
        esac
    fi

    # If DOCKER_HOST points to an unreachable socket, unset it to allow default
    if [[ -n "${DOCKER_HOST:-}" ]] && ! docker info >/dev/null 2>&1; then
        printf "⚠️  DOCKER_HOST='%s' not reachable; falling back to default docker socket.\n" "$DOCKER_HOST"
        unset DOCKER_HOST
    fi

    # Ensure daemon is running
    if ! docker info >/dev/null 2>&1; then
        printf "🔁 Starting Docker daemon...\n"
        require_sudo || true
        sudo systemctl start docker || true
        sleep 2
    fi

    # Fallback to rootless docker if systemd isn't available or daemon still down
    if ! docker info >/dev/null 2>&1; then
        printf "🪄 Trying rootless Docker fallback...\n"
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

begin_step "Check/Install Docker"
# Install Docker if missing and ensure daemon
if ensure_docker; then
    record_ok "Docker available and daemon reachable"
else
    record_fail "Docker setup failed"
fi

begin_step "Install PostgreSQL client (optional)"
# Try to install psql for convenience across distros
if install_postgres_client_any; then
    record_ok "PostgreSQL client installed"
else
    record_warn "PostgreSQL client install skipped/failed"
fi

begin_step "Docker permissions"
# Handle docker group membership; fall back to sudo when needed
DOCKER_PREFIX=""
CURRENT_USER="${SUDO_USER:-${USER:-$(id -un)}}"
if ! id -nG "$CURRENT_USER" | grep -q '\bdocker\b'; then
    echo "⚠️  Adding user '$CURRENT_USER' to 'docker' group (to avoid using sudo)..."
    require_sudo || true
    if sudo usermod -aG docker "$CURRENT_USER"; then
        record_ok "User added to docker group (re-login needed)"
    else
        record_warn "Could not add user to docker group"
    fi
    echo "ℹ️  You'll need to log out/in for group changes to apply. Continuing this run with sudo..."
    DOCKER_PREFIX="sudo "
fi

begin_step "Verify Docker/Compose"
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

# Ensure daemon is actually reachable before continuing (gate compose)
if ! ${DOCKER_PREFIX}docker info >/dev/null 2>&1; then
    record_fail "Docker daemon not reachable"
fi

# If docker socket is present but current user lacks permission, retry via sudo
if ! ${DOCKER_PREFIX}docker info >/dev/null 2>&1; then
    if docker info 2>&1 | grep -qi 'permission denied'; then
        record_warn "Docker socket permission denied for current user; retrying with sudo"
        DOCKER_PREFIX="sudo "
        if ${DOCKER_PREFIX}docker info >/dev/null 2>&1; then
            record_ok "Docker reachable via sudo"
            if ${DOCKER_PREFIX}docker compose version >/dev/null 2>&1; then
                COMPOSE_CMD="${DOCKER_PREFIX}docker compose"
            elif have_cmd docker-compose; then
                COMPOSE_CMD="${DOCKER_PREFIX}docker-compose"
            fi
        fi
    fi
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

begin_step ".env defaults"
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

begin_step "Compose: build and start"
echo "🐳 Building and starting Docker containers..."
# Ensure DOCKER_HOST is propagated to compose if set
if [[ -n "${DOCKER_HOST:-}" ]]; then
    export DOCKER_HOST
fi

# Optional prune of unused images/networks to avoid conflicts
if [[ "${PRUNE_DOCKER:-0}" == "1" ]]; then
    printf "🧹 Pruning unused Docker data...\n"
    ${DOCKER_PREFIX}docker system prune -af --volumes | cat
fi

# Wrapper to run compose and retry with sudo on permission errors
run_compose() {
    local output
    if ! output=$(${COMPOSE_CMD} "$@" 2>&1); then
        echo "$output"
        if echo "$output" | grep -qi 'permission denied'; then
            record_warn "Compose '$*' hit permission denied; retrying with sudo"
            DOCKER_PREFIX="sudo "
            if command -v docker-compose >/dev/null 2>&1; then
                COMPOSE_CMD="${DOCKER_PREFIX}docker-compose"
            else
                COMPOSE_CMD="${DOCKER_PREFIX}docker compose"
            fi
            ${COMPOSE_CMD} "$@" | cat
        else
            return 1
        fi
    fi
}

if run_compose down; then
    record_ok "Compose: stopped any running services"
else
    record_warn "Compose down encountered issues"
fi

if run_compose build --no-cache; then
    record_ok "Compose: images built"
else
    record_fail "Compose build failed"
fi

if run_compose up -d; then
    record_ok "Compose: services started"
else
    record_fail "Compose up failed"
fi

begin_step "Health checks"
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

# Summary is printed by EXIT trap