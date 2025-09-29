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