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
if have_cmd docker && docker compose ps >/dev/null 2>&1; then
  if docker compose ps "$CONTAINER_NAME" | grep -q "Running"; then
    ok "Container '$CONTAINER_NAME' is running"
    # Try host.docker.internal from inside container
    if docker compose exec -T "$CONTAINER_NAME" bash -lc "curl -fsS http://host.docker.internal:11434/api/tags >/dev/null"; then
      ok "Container can reach host Ollama at http://host.docker.internal:11434"
      add_summary "Container→Ollama: OK"
    else
      fail "Container cannot reach host Ollama at http://host.docker.internal:11434"
      warn "If on Linux, ensure extra_hosts: 'host.docker.internal:host-gateway' and bind Ollama: OLLAMA_HOST=0.0.0.0:11434 ollama serve"
      add_summary "Container→Ollama: FAIL"
      HAD_ERROR=1
    fi
  else
    warn "Container '$CONTAINER_NAME' not running"
    add_summary "Container: NOT RUNNING"
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

