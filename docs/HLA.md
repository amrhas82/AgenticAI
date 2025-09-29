# High Level Architecture

## System Overview

AI Agent Playground
├── Frontend (Streamlit Web Interface)
│ ├── Chat Interface
│ ├── Model Selection
│ ├── PDF Upload
│ └── Settings Panel
├── Backend Services
│ ├── Ollama Integration (Local LLMs)
│ ├── PostgreSQL + pgvector (Vector Database)
│ ├── PDF Processing Pipeline
│ ├── JSON Memory System
│ └── MCP Client (Klavis AI)
└── Data Layer
├── Conversation Memory (JSON files)
├── Document Storage (File system)
└── Vector Embeddings (PostgreSQL)

## Data Flow
1. **User Input** → Streamlit Interface → Ollama LLM → Response
2. **PDF Upload** → PyPDF2 Processing → Text Chunks → Vector DB
3. **Chat History** → JSON Memory → Persistent Storage
4. **Vector Search** → PostgreSQL → Similarity Matching → Context
5. **Health/Setup** → `setup.sh` installs deps, brings up containers, checks Postgres + Streamlit

## Technology Stack
- **UI**: Streamlit (Python web framework)
- **AI Models**: Ollama (local LLM management)
- **Vector DB**: PostgreSQL + pgvector
- **Document Processing**: PyPDF2, LangChain text splitters
- **Memory**: JSON file storage
- **Containerization**: Docker + Docker Compose
- **Environment**: Python 3.9+, Linux (Windows via WSL2)

## Deployment & Ops
- Self-diagnosing setup: `setup.sh` performs Docker install (apt-based), builds services, and prints a summary of success/failure.
- Health checks:
  - Dockerfile defines a Streamlit HEALTHCHECK
  - Setup waits on `http://localhost:8501/_stcore/health` and probes Postgres via psql