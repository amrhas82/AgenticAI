#!/usr/bin/env bash
set -euo pipefail

# Simple post-setup verifier for AgenticAI
# - Checks Streamlit health
# - Checks Ollama availability on host
# - If Docker is available and streamlit container is running, checks connectivity from inside container to host Ollama
# - Prints a concise summary and suggested fixes

RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"

ok() { printf "%b✅ %s%b\n" "$GREEN" "$1" "$RESET"; }
warn() { printf "%b⚠️  %s%b\n" "$YELLOW" "$1" "$RESET"; }
fail() { printf "%b❌ %s%b\n" "$RED" "$1" "$RESET"; }

HAD_ERROR=0

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Resolve absolute path to this script (for locating project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Compose helpers
COMPOSE_CMD=""
COMPOSE_DIR=""

detect_compose_cmd() {
  if have_cmd docker && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  elif have_cmd docker-compose; then
    COMPOSE_CMD="docker-compose"
  else
    COMPOSE_CMD=""
  fi
}

find_compose_dir() {
  # Prefer repo root (one level up from scripts), else current dir
  local candidates=("${SCRIPT_DIR}/.." "$PWD")
  for d in "${candidates[@]}"; do
    if [[ -f "$d/docker-compose.yml" || -f "$d/docker-compose.yaml" ]]; then
      COMPOSE_DIR="$d"
      return 0
    fi
  done
  COMPOSE_DIR=""
  return 1
}

compose_service_running() {
  # Try multiple strategies for robustness across compose versions
  # 1) services filtered by running status
  if $COMPOSE_CMD ps --status running --services 2>/dev/null | grep -qx "$CONTAINER_NAME"; then
    return 0
  fi
  # 2) JSON output with running state
  if $COMPOSE_CMD ps --format json 2>/dev/null | grep -q '"Service":"'"$CONTAINER_NAME"'"' && \
     $COMPOSE_CMD ps --format json 2>/dev/null | grep -q '"State":"running"'; then
    return 0
  fi
  # 3) Plain output containing Up/healthy
  if $COMPOSE_CMD ps "$CONTAINER_NAME" 2>/dev/null | grep -Eiq 'Up|running|healthy'; then
    return 0
  fi
  return 1
}

port_in_use_info() {
  local port="$1"
  if have_cmd ss && ss -ltnp 2>/dev/null | grep -q ":${port} "; then
    ss -ltnp | grep ":${port} " | sed 's/^/   /'
    return 0
  elif have_cmd lsof && lsof -i :"$port" 2>/dev/null | sed 's/^/   /' | head -n 1 | grep -q ":${port}$"; then
    lsof -i :"$port" | sed 's/^/   /'
    return 0
  fi
  return 1
}

section() { printf "\n==== %s ====\n" "$1"; }

summary_items=()
add_summary() { summary_items+=("$1"); }

STREAMLIT_URL="http://localhost:8501/_stcore/health"
OLLAMA_HOST_NATIVE="http://localhost:11434"
CONTAINER_NAME="streamlit-app"

section "Streamlit"
if curl -fsS "$STREAMLIT_URL" >/dev/null 2>&1; then
  ok "Streamlit responded at $STREAMLIT_URL"
  add_summary "Streamlit: OK"
else
  fail "Streamlit not reachable at $STREAMLIT_URL"
  add_summary "Streamlit: FAIL"
  HAD_ERROR=1
fi

section "Ollama (host)"
if have_cmd ollama; then
  if curl -fsS "$OLLAMA_HOST_NATIVE/api/tags" >/dev/null 2>&1; then
    ok "Ollama reachable at $OLLAMA_HOST_NATIVE"
    add_summary "Ollama(host): OK"
  else
    # Try to start it if possible
    if pgrep -f "ollama serve" >/dev/null 2>&1; then
      fail "Ollama process running but $OLLAMA_HOST_NATIVE not reachable"
    else
      warn "Ollama not detected; attempting to start 'ollama serve' in background"
      (OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve >/tmp/ollama.out 2>&1 &)
      sleep 2
      if curl -fsS "$OLLAMA_HOST_NATIVE/api/tags" >/dev/null 2>&1; then
        ok "Started Ollama and verified at $OLLAMA_HOST_NATIVE"
      else
        fail "Unable to reach Ollama at $OLLAMA_HOST_NATIVE"
        HAD_ERROR=1
      fi
    fi
    add_summary "Ollama(host): ${HAD_ERROR:+FAIL}" 
  fi
  # Show models if available
  if have_cmd ollama && ollama list >/dev/null 2>&1; then
    ok "Installed models:"; ollama list | sed 's/^/  /'
  fi
else
  warn "'ollama' CLI not found on host. Skipping host checks."
  add_summary "Ollama(host): SKIP"
fi

section "Docker & in-container connectivity"
if have_cmd docker; then
  detect_compose_cmd
  if [[ -z "$COMPOSE_CMD" ]]; then
    warn "Docker Compose not available; skipping container checks"
    add_summary "Docker: NO COMPOSE"
  else
    if ! find_compose_dir; then
      warn "Could not locate docker-compose.yml; looked in '${SCRIPT_DIR}/..' and '$PWD'"
      add_summary "Container: COMPOSE FILE MISSING"
      HAD_ERROR=1
    else
      pushd "$COMPOSE_DIR" >/dev/null
      if compose_service_running; then
        ok "Container '$CONTAINER_NAME' is running"
        add_summary "Container: RUNNING"
      else
        warn "Container '$CONTAINER_NAME' not running"
        if port_in_use_info 8501; then
          warn "Port 8501 is already in use (details above). If this isn't Docker, update port mapping in docker-compose.yml (e.g. '8502:8501')."
        fi
        if $COMPOSE_CMD up -d "$CONTAINER_NAME" >/dev/null 2>&1; then
          ok "Started container '$CONTAINER_NAME'"
        else
          fail "Failed to start container '$CONTAINER_NAME'"
          $COMPOSE_CMD ps | sed 's/^/   /' || true
          $COMPOSE_CMD logs --tail=200 "$CONTAINER_NAME" | sed 's/^/   /' || true
          add_summary "Container: START FAILED"
          HAD_ERROR=1
        fi
      fi

      if compose_service_running; then
        if $COMPOSE_CMD exec -T "$CONTAINER_NAME" bash -lc "curl -fsS http://host.docker.internal:11434/api/tags >/dev/null"; then
          ok "Container can reach host Ollama at http://host.docker.internal:11434"
          add_summary "Container→Ollama: OK"
        elif $COMPOSE_CMD exec -T "$CONTAINER_NAME" bash -lc "curl -fsS http://gateway.docker.internal:11434/api/tags >/dev/null"; then
          ok "Container can reach host Ollama at http://gateway.docker.internal:11434"
          add_summary "Container→Ollama: OK (via gateway.docker.internal)"
        else
          fail "Container cannot reach host Ollama on host.docker.internal:11434 or gateway.docker.internal:11434"
          warn "On Linux: ensure Ollama listens on 0.0.0.0:11434 and, for rootless Docker, try 'gateway.docker.internal'."
          warn "Compose 'extra_hosts' mapping is present; some rootless setups ignore 'host-gateway'."
          add_summary "Container→Ollama: FAIL"
          HAD_ERROR=1
        fi
      else
        add_summary "Container: NOT RUNNING"
        HAD_ERROR=1
      fi
      popd >/dev/null
    fi
  fi
else
  warn "Docker not available; skipping container checks"
  add_summary "Docker: SKIP"
fi

section "Summary"
for item in "${summary_items[@]}"; do
  echo "- $item"
done

echo
if [[ $HAD_ERROR -ne 0 ]]; then
  cat << 'EOF'
Next steps:
- Ensure Ollama is bound to 0.0.0.0 for Docker: OLLAMA_HOST=0.0.0.0:11434 ollama serve
- Verify tags on host: curl http://localhost:11434/api/tags
- If container cannot reach host, confirm docker-compose has:
    extra_hosts:
      - "host.docker.internal:host-gateway"
- Restart services: docker compose restart
- View logs: docker compose logs -f streamlit-app | cat
EOF
  exit 1
else
  echo "All critical health checks passed."
fi

