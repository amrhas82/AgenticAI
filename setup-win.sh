#!/usr/bin/env bash

set -Euo pipefail
set +H  # Disable history expansion to avoid 'event not found' on some Windows/WSL shells

echo "🚀 Setting up AI Agent Playground (Windows/WSL) ..."

SUMMARY=""
FAIL_COUNT=0
CURRENT_STEP="startup"

record_ok() { SUMMARY+=$'\n'"✅ $1"; }
record_warn() { SUMMARY+=$'\n'"⚠️  $1"; }
record_fail() { SUMMARY+=$'\n'"❌ $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

begin_step() { CURRENT_STEP="$1"; printf "\n— %s —\n" "$1"; }

print_summary() {
  printf "\n==============================\n"
  printf "Setup summary\n"
  printf "==============================\n"
  printf "%s\n" "$SUMMARY"
  if (( FAIL_COUNT > 0 )); then
    printf "\nSome issues were detected (failures: %s).\n" "$FAIL_COUNT"
    if [[ -n "${COMPOSE_CMD:-}" ]]; then
      printf "View logs: %s logs --tail=200 | cat\n" "$COMPOSE_CMD"
    fi
    exit 1
  else
    printf "\n✅ Setup complete!\n"
    printf "🌐 Streamlit app: http://localhost:8501\n"
    printf "🗄️  PostgreSQL (in Docker): localhost:5432\n"
    if [[ -n "${COMPOSE_CMD:-}" ]]; then
      printf "\n📋 Useful commands:\n"
      printf "   View logs: %s logs -f streamlit-app | cat\n" "$COMPOSE_CMD"
      printf "   Stop services: %s down\n" "$COMPOSE_CMD"
      printf "   Restart: %s restart\n" "$COMPOSE_CMD"
    fi
  fi
}

handle_err() {
  local line="$1"; local cmd="$2"
  if [[ "$cmd" == docker* || "$cmd" == *" docker "* || "$cmd" == *"docker compose"* ]]; then
    record_fail "Docker command failed in step '${CURRENT_STEP}': ${cmd}"
    record_warn "Ensure Docker Desktop is running and WSL2 integration is enabled."
  else
    record_fail "Error in step '${CURRENT_STEP}' at line ${line}: ${cmd}"
  fi
}

trap 'handle_err "$LINENO" "$BASH_COMMAND"' ERR
trap 'print_summary' EXIT

have_cmd() { command -v "$1" >/dev/null 2>&1; }

begin_step "Detect environment"
OS_NAME="$(uname -s || echo Unknown)"
IS_WSL=false
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then IS_WSL=true; fi
record_ok "Host: ${OS_NAME}${IS_WSL:+ (WSL)}"

begin_step "Verify Docker/Compose"
if ! have_cmd docker; then
  record_fail "docker not found. Install Docker Desktop for Windows and enable WSL2 integration."
else
  docker --version | sed 's/^/✅ /'
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif have_cmd docker-compose; then
  COMPOSE_CMD="docker-compose"
else
  record_fail "Docker Compose not available. Install Docker Desktop or the compose plugin."
fi

# Set host networking addresses for WSL/Windows
begin_step "Environment defaults"
if [ ! -f .env ]; then
  echo "📝 Creating default .env file..."
  cat > .env << 'EOF'
# Local development defaults
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://localhost:8080
EOF
  record_ok ".env created"
else
  record_ok ".env present"
fi

begin_step "Compose: build and start"
# Guard against unset COMPOSE_CMD when Compose is missing
if [[ -z "${COMPOSE_CMD:-}" ]]; then
  record_fail "Docker Compose not available; skipping build/start"
else
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
fi

begin_step "Health checks"
# Basic HTTP wait for Streamlit (shorter timeout on Windows/WSL)
wait_for_http() {
  local url="$1"; local timeout="${2:-60}"; local i=0
  while (( i < timeout )); do
    if curl -fsS "$url" >/dev/null 2>&1; then return 0; fi
    sleep 1; i=$((i+1))
  done
  return 1
}

if wait_for_http "http://localhost:8501/_stcore/health" 60; then
  record_ok "Streamlit health endpoint responded"
else
  record_fail "Streamlit did not respond on http://localhost:8501"
  # Print recent logs to aid debugging
  if [[ -n "${COMPOSE_CMD:-}" ]]; then
    ${COMPOSE_CMD} logs --tail=200 | cat || true
  fi
fi

