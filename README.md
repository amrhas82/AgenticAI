# AI Agent Playground 🚀

A complete local AI agent playground for learning and experimentation. No API keys, no internet required after setup!

## ✨ Features

✅ **Local LLMs** - Full Ollama integration (llama2, mistral, codellama, etc.)  
✅ **MCP Support** - Klavis MCP self-hosted integration  
✅ **Persistent Memory** - JSON-based conversation history with search & tags  
✅ **Multi-Format Documents** - PDF, TXT, MD, DOCX support  
✅ **Vector Database** - PostgreSQL + pgvector with JSON fallback  
✅ **External LLMs** - OpenAI API support  
✅ **API Key Management** - Secure authentication for external agents  
✅ **RAG System** - Semantic search with reranking  
✅ **Multi-Agent System** - Specialized agents with tools

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

The Streamlit UI includes multiple agents (General Chat, RAG Assistant, Coder) and supports uploading pdf/txt/md/docx files.

## 📚 Documentation

### Quick Links
- **[🚀 Quick Start](QUICK_START.md)** - Get running in 5 minutes
- **[✅ Completion Report](COMPLETION_REPORT.md)** - All features verified
- **[📋 Review Summary](REVIEW_SUMMARY.md)** - Detailed implementation review

### Full Documentation
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

### Install Docker on Ubuntu (manual) and rootless mode
- See the Setup Guide for step-by-step commands:
  - [Manual Docker install (Ubuntu 24.04+/25.04)](docs/SETUP.md#manual-docker-install-ubuntu-2404-2504)
  - [Optional: Rootless Docker](docs/SETUP.md#optional-rootless-docker)

### Rootless Docker / custom DOCKER_HOST
- If you use rootless Docker, ensure `DOCKER_HOST` points to your socket (e.g., `unix:///run/user/1000/docker.sock`). The setup will fall back if it detects an unreachable `DOCKER_HOST`.

### Permission denied to /var/run/docker.sock
- The setup scripts detect this and retry with `sudo` when possible.
- To fix permanently: add your user to the `docker` group (see above), then log out/in.

### Health checks and logs
- The setup scripts wait for Streamlit at `http://localhost:8501/_stcore/health` and check Postgres.
- Both scripts print a step-wise summary at the end, including any failures and a hint to view logs.
- View logs: `docker compose logs -f | cat`
- Streamlit-only logs: `docker compose logs -f streamlit-app | cat`

### Windows/WSL without admin (Docker unavailable)
- If you cannot install or enable Docker Desktop/WSL integration, follow the diagnostics in the Setup Guide section "Windows/WSL without admin (Docker unavailable)". This includes tracing `setup-win.sh`, showing detailed compose build progress, checking service logs, and probing the Streamlit health endpoint.
- See: [Setup Guide → Windows/WSL without admin](docs/SETUP.md#windowswsl-without-admin-docker-unavailable)

### Cleanup before rebuilds
- To prune unused images/networks/volumes before a rebuild, run:
```bash
PRUNE_DOCKER=1 ./setup.sh
```

## Ollama: add and manage local models

Ensure Ollama is running (Linux: `ollama serve`; macOS/Windows: start the Ollama app). Then use the following commands:

```bash
# Pull models (downloads models for local use)
ollama pull llama3
ollama pull mistral
ollama pull qwen2.5:7b
ollama pull phi3:mini

# Coding-focused model
ollama pull codellama:7b-instruct

# Embeddings (used for RAG)
ollama pull nomic-embed-text

# Run a model interactively
ollama run llama3

# List installed models
ollama list

# Remove a model
ollama rm <model-name>

# Build a custom model from a Modelfile (example)
# Save the following as Modelfile in your current directory:
#
#   FROM llama3
#   SYSTEM You are a concise helpful assistant.
#
# Then build and run:
ollama create mymodel -f Modelfile
ollama run mymodel
```

Notes for this app
- The app now respects `OLLAMA_HOST` everywhere (chat and embeddings). Set it to the reachable URL from where Streamlit runs.
  - If running Streamlit locally (no Docker): `export OLLAMA_HOST=http://localhost:11434`
  - If running in Docker on Linux: keep `extra_hosts` and set `OLLAMA_HOST=http://host.docker.internal:11434` in `docker-compose.yml`.
    - If requests from the container fail: start Ollama bound to all interfaces so the container can reach it: `pkill -f "ollama serve" || true && OLLAMA_HOST=0.0.0.0:11434 ollama serve &`
  - Verify connectivity from the same context as Streamlit:
    ```bash
    curl -sS $OLLAMA_HOST/api/tags | jq '.' | head -n 20 || curl -sS $OLLAMA_HOST/api/tags
    ```
- After pulling a new chat model, you do not need to restart the model server, but you may need to reload the Streamlit page to see it in the “Choose Local Model” list.
- To change the embedding model used by the app, set `EMBED_MODEL` in `.env` (e.g., `nomic-embed-text`) and restart:
```bash
docker compose restart
```

### Port conflicts
- Change published ports in `docker-compose.yml` if 8501 or 5432 are taken.

## UI notes
- Theme toggle (Light/Dark) works via the sidebar and applies immediately.
- MCP URL can be configured from the sidebar; status will show reachable/unreachable info.