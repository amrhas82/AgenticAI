## Troubleshooting

Use this guide to quickly map common errors to fixes.

### Container cannot reach Ollama
Error (inside container):
```bash
curl: (7) Failed to connect to host.docker.internal port 11434: Could not connect to server
```
Meaning:
- The Streamlit container cannot reach the Ollama server on your host.

Fix:
- On Linux, bind Ollama to all interfaces and ensure the compose alias is present.
```bash
pkill -f "ollama serve" || true
OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve >/tmp/ollama.out 2>&1 &
```
- Confirm `docker-compose.yml` has:
```yaml
services:
  streamlit-app:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - OLLAMA_HOST=http://host.docker.internal:11434
```
- Restart and re-test:
```bash
docker compose restart streamlit-app
docker compose exec streamlit-app curl -sS http://host.docker.internal:11434/api/tags
```
- If it still fails, check local firewall rules for port 11434 from the Docker bridge network.

### Streamlit health fails
Error:
```bash
curl http://localhost:8501/_stcore/health  # fails
```
Meaning:
- The UI is not running or the port is occupied.

Fix:
- Start or restart:
```bash
docker compose up -d
docker compose logs -f streamlit-app | cat
```
- If port 8501 is in use, change the published port in `docker-compose.yml` (e.g., `"8502:8501"`) and restart.

### Application error: 'id'
Symptom:
- UI shows: `Application error: 'id'`

Meaning:
- A saved conversation lacks an `id` field; the UI expects it.

Fix:
```bash
printf '{\n  "conversations": []\n}\n' > data/memory/conversations.json
```
Reload the page.

### No local models found
Symptom:
- Model picker is empty or defaults only; responses fail.

Fix:
```bash
ollama list
ollama pull llama3           # or mistral, etc.
ollama pull nomic-embed-text # for embeddings (optional)
```

### Settings: Ollama host confusion
Rules of thumb:
- Running Streamlit in Docker: use `http://host.docker.internal:11434` in Settings (container → host).
- Running Streamlit natively: use `http://localhost:11434`.

### OpenAI provider requires API key
Symptom:
- OpenAI responses do not start or an API key warning appears.

Fix:
- Add key in the sidebar or set env var before launch:
```bash
export OPENAI_API_KEY=sk-...
```

### Quick overall health
Run the consolidated check:
```bash
bash scripts/health_check.sh
```
It summarizes Streamlit, host Ollama, and container-to-host connectivity with suggested next steps.

