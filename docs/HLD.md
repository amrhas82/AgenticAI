# High Level Design

## Component Architecture

### 1. Streamlit Application (`src/app.py`)
```python
class AIPlaygroundApp:
    ├── setup_sidebar(): Model selection, file upload, settings
    ├── display_chat(): Chat interface, message history
    ├── ollama_client: LLM communication
    ├── memory_manager: Conversation persistence
    ├── pdf_processor: Document text extraction
    ├── vector_db: Vector storage and search
    └── mcp_client: External service integration
```

### 2. Services and environment
- Streamlit runs in a container built from `Dockerfile` (Python 3.9-slim)
- `docker-compose.yml` orchestrates:
  - `postgres` with `pgvector` extension
  - `streamlit-app` exposing port 8501
- Environment variables:
  - `DATABASE_URL` for Postgres connection
  - `OLLAMA_HOST`, `EMBED_MODEL`, `EMBED_DIM`, `MCP_URL`

### 3. Health checks and setup
- Dockerfile defines a `HEALTHCHECK` probing `http://localhost:8501/_stcore/health`
- `setup.sh`:
  - Installs Docker/Compose on apt-based distros
  - Adds the user to the `docker` group
  - Builds and starts containers
  - Waits for Postgres (via `psql`) and Streamlit health endpoint
  - Prints a summary of successes/failures

### 4. Error handling patterns
- UI safeguards around model listing, RAG retrieval, and document parsing
- Import-time errors surface to Streamlit with actionable messages

### 5. File handling
- Uploads accept `pdf`, `txt`, `md`
- PDFs parsed via PyPDF2; plain text split into overlapping chunks
- Chunks stored in Postgres with pgvector for similarity search
