# AI Agent System Architecture Diagrams

Visual representations of the AI agent system architecture and data flows.

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Streamlit UI (app.py)                       │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │   Chat   │  │Documents │  │   Convos │  │ Settings │          │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
└────────────────────────┬────────────────────────────────────────────┘
                         │
           ┌─────────────┼─────────────┐
           │             │             │
           ▼             ▼             ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │  Agent   │  │ Document │  │ Memory   │
    │ Registry │  │ Manager  │  │ Manager  │
    └─────┬────┘  └────┬─────┘  └────┬─────┘
          │            │              │
          │            │              │
    ┌─────▼─────────┬──▼──────┬──────▼────────┐
    │               │         │               │
    │  Agent Pool   │Vector DB│ conversations │
    │               │         │   .json       │
    │ - General     │ ┌─────┐ │               │
    │ - RAG         │ │ PG  │ │   ┌────────┐  │
    │ - Coder       │ │+vec │ │   │ Tags   │  │
    │ - Research    │ │ OR  │ │   │ Meta   │  │
    │ - MCP         │ │JSON │ │   │ Search │  │
    │               │ └─────┘ │   └────────┘  │
    └───────────────┴─────────┴───────────────┘
```

## 2. Agent Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Agent                                │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │              AgentConfig                         │       │
│  │  - name: "RAG Assistant"                         │       │
│  │  - system_prompt: "You are..."                   │       │
│  │  - temperature: 0.5                              │       │
│  │  - max_tokens: 2000                              │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │              Tools (Dict)                        │       │
│  │                                                  │       │
│  │  "search_documents"  → SearchTool                │       │
│  │  "recall_conversation" → MemoryTool              │       │
│  │  "execute_code"      → CodeExecutorTool          │       │
│  │  "mcp_web_search"    → MCPTool                   │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │      conversation_history (List[Dict])           │       │
│  │                                                  │       │
│  │  [{"role": "user", "content": "..."},           │       │
│  │   {"role": "assistant", "content": "..."}]      │       │
│  └──────────────────────────────────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────────┐       │
│  │           Methods                                │       │
│  │                                                  │       │
│  │  - process_message()                             │       │
│  │  - add_tool()                                    │       │
│  │  - get_system_prompt()                           │       │
│  │  - clear_history()                               │       │
│  └──────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────┘
```

## 3. Conversation History Flow

### Current Implementation (Shared)

```
User sends message
        │
        ▼
┌───────────────────────────────────────┐
│   st.session_state.messages           │ ← Shared across all agents
│   [{"role": "user", "content": "Hi"}] │
└───────────┬───────────────────────────┘
            │
            ▼
    Select Agent (e.g., "RAG Assistant")
            │
            ▼
┌───────────────────────────────────────┐
│   Agent.process_message()             │
│   - Adds to agent.conversation_history│ ← Temporary, per agent instance
└───────────┬───────────────────────────┘
            │
            ▼
    User clicks "Save Conversation"
            │
            ▼
┌───────────────────────────────────────┐
│   EnhancedMemoryManager               │
│   .save_conversation()                │
│                                       │
│   → conversations.json                │ ← Single shared file
│   {                                   │
│     "id": "abc123",                   │
│     "messages": [...],                │
│     "tags": [],                       │ ← Can filter by agent
│     "metadata": {}                    │
│   }                                   │
└───────────────────────────────────────┘
```

### Improved Implementation (Tag-Based Filtering)

```
User sends message
        │
        ▼
┌───────────────────────────────────────┐
│   st.session_state.messages           │
└───────────┬───────────────────────────┘
            │
            ▼
    Select Agent: "RAG Assistant"
            │
            ▼
┌───────────────────────────────────────┐
│   Agent.process_message()             │
└───────────┬───────────────────────────┘
            │
            ▼
    Auto-save with agent metadata
            │
            ▼
┌───────────────────────────────────────────────────────┐
│   EnhancedMemoryManager.save_conversation()           │
│   → conversations.json                                │
│   {                                                   │
│     "id": "abc123",                                   │
│     "messages": [...],                                │
│     "tags": ["RAG Assistant"],         ← Agent tag!   │
│     "metadata": {                                     │
│       "agent_name": "RAG Assistant",   ← Agent name   │
│       "temperature": 0.5,                             │
│       "tools_used": ["search_documents"]              │
│     }                                                 │
│   }                                                   │
└───────────────────────────────────────────────────────┘
            │
            ▼
    Load conversations by agent
            │
            ▼
┌───────────────────────────────────────────────────────┐
│   memory.load_conversations(tags=["RAG Assistant"])  │
│   → Returns only RAG Assistant conversations          │
└───────────────────────────────────────────────────────┘
```

## 4. Document Processing and RAG Flow

```
User uploads document (e.g., "report.pdf")
        │
        ▼
┌─────────────────────────────────────────────────┐
│   DocumentProcessor.process_file()              │
│                                                 │
│   1. Detect file type (PDF/TXT/DOCX/MD)        │
│   2. Extract text                              │
│   3. Split into chunks (1000 words + overlap)  │
│                                                 │
│   Output: ["chunk1", "chunk2", ...]            │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│   VectorDB.store_document()                     │
│                                                 │
│   For each chunk:                               │
│   1. Generate embedding via Ollama              │
│      (nomic-embed-text → 768-dim vector)       │
│   2. Store in database                          │
└─────────────┬───────────────────────────────────┘
              │
              ├─── PostgreSQL (preferred) ───────────┐
              │                                      │
              │    ┌──────────────────────────────┐  │
              │    │ document_embeddings table    │  │
              │    │ ┌─────────┬─────────────┐    │  │
              │    │ │ id      │ SERIAL      │    │  │
              │    │ │ doc_name│ TEXT        │    │  │
              │    │ │ chunk   │ TEXT        │    │  │
              │    │ │ embedding│ VECTOR(768)│    │  │
              │    │ │ metadata│ JSONB       │    │  │
              │    │ └─────────┴─────────────┘    │  │
              │    └──────────────────────────────┘  │
              │                                      │
              └─── JSON fallback ────────────────────┤
                                                     │
                   ┌──────────────────────────────┐  │
                   │ vector_store.json            │  │
                   │ [                            │  │
                   │   {                          │  │
                   │     "document_name": "...",  │  │
                   │     "chunk_text": "...",     │  │
                   │     "embedding": [0.1, ...], │  │
                   │     "metadata": {            │  │
                   │       "agent": "RAG Asst"    │  │
                   │     }                        │  │
                   │   }                          │  │
                   │ ]                            │  │
                   └──────────────────────────────┘  │
                                                     │
              ┌──────────────────────────────────────┘
              │
              ▼
    Documents ready for search!

─────────────────────────────────────────────────────────

User asks: "What does the report say about X?"
        │
        ▼
┌─────────────────────────────────────────────────┐
│   Agent (RAG Assistant) detects document query  │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│   Agent calls SearchTool.execute(query="X")     │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│   VectorDB.search_similar(query="X", limit=5)  │
│                                                 │
│   1. Generate query embedding                   │
│   2. Compute cosine similarity                  │
│   3. Return top-k chunks                        │
│                                                 │
│   Output: ["relevant chunk 1", ...]            │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│   Agent receives chunks as tool result          │
│   Creates prompt with context:                  │
│                                                 │
│   "Based on these documents:                    │
│    [chunk 1]                                    │
│    [chunk 2]                                    │
│                                                 │
│    Answer: What does the report say about X?"   │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│   LLM generates response with citations         │
│   → Displayed to user                           │
└─────────────────────────────────────────────────┘
```

## 5. MCP Integration Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     AI Agent System                          │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │              Agent Registry                     │         │
│  │                                                 │         │
│  │  Creates agents with tools:                    │         │
│  │  ┌──────────────────────────────────────────┐  │         │
│  │  │  RAG Agent                               │  │         │
│  │  │  - SearchTool (vector DB)                │  │         │
│  │  │  - MemoryTool                            │  │         │
│  │  │  - MCPTool (web_search)    ← MCP!        │  │         │
│  │  │  - MCPTool (file_read)     ← MCP!        │  │         │
│  │  └──────────────────────────────────────────┘  │         │
│  └────────────────────────────────────────────────┘         │
│                         │                                    │
│                         │ Uses                               │
│                         ▼                                    │
│  ┌────────────────────────────────────────────────┐         │
│  │              MCPClient                          │         │
│  │  (src/mcp_client.py)                           │         │
│  │                                                 │         │
│  │  Methods:                                      │         │
│  │  - list_tools()                                │         │
│  │  - call_tool(name, params)                     │         │
│  │  - list_resources()                            │         │
│  │  - read_resource(uri)                          │         │
│  │  - get_prompts()                               │         │
│  └────────────────┬───────────────────────────────┘         │
│                   │                                          │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    │ HTTP/REST API
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│               MCP Server (Klavis)                            │
│               http://localhost:8080                          │
│                                                              │
│  Endpoints:                                                  │
│  ┌────────────────────────────────────────────────┐         │
│  │  GET  /health            → Status check        │         │
│  │  GET  /api/tools         → List tools          │         │
│  │  POST /api/tools/execute → Execute tool        │         │
│  │  GET  /api/resources     → List resources      │         │
│  │  GET  /api/prompts       → Get prompt templates│         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  Available Tools:                                            │
│  ┌────────────────────────────────────────────────┐         │
│  │  - web_search (query)                          │         │
│  │  - file_read (path)                            │         │
│  │  - file_write (path, content)                  │         │
│  │  - database_query (sql)                        │         │
│  │  - http_request (url, method, params)          │         │
│  │  - shell_execute (command)                     │         │
│  └────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────┘
```

### MCP Tool Call Flow

```
User: "Search the web for Python tutorials"
        │
        ▼
┌─────────────────────────────────────────────┐
│   Agent (MCP Assistant) process_message()   │
│   - Detects web search intent               │
│   - Generates tool call JSON                │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│   Agent executes MCPTool                    │
│   tool_name = "web_search"                  │
│   params = {"query": "Python tutorials"}    │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│   MCPClient.call_tool()                     │
│   POST http://localhost:8080/api/tools/execute │
│   Body: {                                   │
│     "tool": "web_search",                   │
│     "parameters": {"query": "..."}          │
│   }                                         │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│   MCP Server executes web search            │
│   Returns: {                                │
│     "success": true,                        │
│     "data": {                               │
│       "results": [...]                      │
│     }                                       │
│   }                                         │
└─────────────┬───────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│   Agent receives results                    │
│   Generates natural language response       │
│   "Here are Python tutorials I found..."    │
└─────────────────────────────────────────────┘
```

## 6. Agent-Specific Document Storage

### Without Agent Filtering (Current Default)

```
┌────────────────────────────────────────────────────┐
│            Vector Database                         │
│                                                    │
│  All documents mixed together:                     │
│  ┌──────────────────────────────────────────────┐ │
│  │ doc1.pdf (uploaded by RAG Agent)             │ │
│  │ doc2.txt (uploaded by Research Agent)        │ │
│  │ doc3.pdf (uploaded by RAG Agent)             │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  Any agent can search all documents               │
└────────────────────────────────────────────────────┘
```

### With Agent Filtering (Improved)

```
┌────────────────────────────────────────────────────────────┐
│            Vector Database with Metadata                   │
│                                                            │
│  Documents tagged by agent:                                │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ doc1.pdf                                             │ │
│  │   metadata: {"agent": "RAG Assistant"}               │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │ doc2.txt                                             │ │
│  │   metadata: {"agent": "Research Assistant"}          │ │
│  ├──────────────────────────────────────────────────────┤ │
│  │ doc3.pdf                                             │ │
│  │   metadata: {"agent": "RAG Assistant"}               │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  Search with filter:                                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ search_similar(query, agent_filter="RAG Assistant")  │ │
│  │ → Returns only doc1.pdf and doc3.pdf chunks          │ │
│  └──────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

## 7. Complete System Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│                         (Streamlit)                             │
└───┬─────────────────────────────────────────────────────────┬───┘
    │                                                         │
    │ 1. Send message                              2. Upload doc
    │                                                         │
    ▼                                                         ▼
┌───────────────────────┐                      ┌──────────────────┐
│   Agent Registry      │                      │ Document Manager │
│   - Select agent      │                      │ - Process file   │
│   - Get tools         │                      │ - Create chunks  │
└───┬───────────────────┘                      └────┬─────────────┘
    │                                                │
    ▼                                                │
┌───────────────────────┐                           │
│   Agent               │                           │
│   - Process message   │                           │
│   - Check for tools   │                           │
│   - Generate response │                           │
└───┬───────────────────┘                           │
    │                                                │
    │ 3. Need document info?                         │
    │                                                │
    ▼                                                │
┌───────────────────────┐                           │
│   SearchTool          │                           │
│   - Execute search    │◄──────────────────────────┘
└───┬───────────────────┘   4. Store in vector DB
    │
    ▼
┌───────────────────────────────────────────────────────────┐
│                    Vector Database                        │
│   - PostgreSQL + pgvector (or JSON fallback)              │
│   - Store: embeddings + metadata                          │
│   - Search: cosine similarity                             │
└───┬───────────────────────────────────────────────────────┘
    │
    │ 5. Return results
    │
    ▼
┌───────────────────────┐
│   Agent               │
│   - Format response   │
│   - Add citations     │
└───┬───────────────────┘
    │
    │ 6. Return to user
    │
    ▼
┌───────────────────────────────────────────────────────────┐
│                    Memory Manager                         │
│   - Save conversation with agent tags                     │
│   - Store in conversations.json                           │
└───────────────────────────────────────────────────────────┘
    │
    │ 7. Available for recall
    │
    ▼
┌───────────────────────┐
│   MemoryTool          │
│   - Search past convos│
│   - Filter by agent   │
└───────────────────────┘
```

## 8. Tool Execution Decision Tree

```
Agent receives message
        │
        ▼
   Parse intent
        │
        ├─── Document query? ──→ Use SearchTool ──→ Vector DB
        │                                              │
        │                                              ▼
        │                                         Return chunks
        │
        ├─── Code execution? ──→ Use CodeExecutorTool
        │                                              │
        │                                              ▼
        │                                         Run sandboxed
        │
        ├─── Past conversation? ─→ Use MemoryTool
        │                                              │
        │                                              ▼
        │                                         Search JSON
        │
        ├─── Web/File/API? ───→ Use MCPTool ──→ MCP Server
        │                                              │
        │                                              ▼
        │                                         External tool
        │
        └─── General query ────→ Direct LLM ──→ Generate response
                                                      │
                                                      ▼
                                              Return to user
```

## 9. Session State Management

```
┌────────────────────────────────────────────────────────────┐
│                 st.session_state                           │
│                                                            │
│  Global state across page reloads:                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  messages: [{"role": "user", "content": "..."}]      │ │
│  │  provider: "Local (Ollama)" | "OpenAI"               │ │
│  │  current_agent: "RAG Assistant"                      │ │
│  │  current_model: "llama2"                             │ │
│  │  use_rag: True | False                               │ │
│  │  current_conversation_id: "abc123"                   │ │
│  │  page: "Chat" | "Documents" | "Conversations"        │ │
│  │  theme: "light" | "dark"                             │ │
│  │  mcp_url: "http://localhost:8080"                    │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  Temporary UI state:                                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  search_active: True | False                         │ │
│  │  edit_tags_for: "conversation_id"                    │ │
│  │  loaded_conversation_id: "abc123"                    │ │
│  └──────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

## 10. File System Layout

```
/workspace/
│
├── data/                           # Runtime data (not in git)
│   ├── memory/
│   │   ├── conversations.json      # All conversation history
│   │   ├── vector_store.json       # Vector embeddings (JSON mode)
│   │   └── test_conv.json
│   ├── documents/
│   │   └── example.pdf             # Uploaded documents
│   └── config/
│       └── system_config.json
│
├── src/
│   ├── agents/
│   │   └── agent_system.py         # Agent definitions, tools, registry
│   ├── ui/
│   │   ├── conversation_manager.py # Conversation CRUD + UI
│   │   └── document_manager.py     # Document upload + UI
│   ├── database/
│   │   └── enhanced_vector_db.py
│   ├── utils/
│   │   └── config_manager.py
│   ├── app.py                      # Main Streamlit app
│   ├── mcp_client.py               # MCP integration
│   ├── vector_db.py                # Vector storage
│   ├── document_processor.py       # File parsing (PDF/TXT/DOCX)
│   ├── ollama_client.py            # Ollama LLM client
│   └── openai_client.py            # OpenAI API client
│
├── docs/
│   ├── AI_AGENT_GUIDE.md           # Complete guide (NEW!)
│   ├── AGENT_ARCHITECTURE_DIAGRAM.md # This file
│   ├── HLA.md
│   ├── HLD.md
│   └── SETUP.md
│
├── docker-compose.yml              # Container orchestration
├── Dockerfile                      # Streamlit app container
├── requirements.txt                # Python dependencies
├── .env                            # Environment config
└── README.md                       # Project overview
```

---

## Quick Reference: Component Relationships

| Component | Uses | Provides To |
|-----------|------|-------------|
| `app.py` | All modules | UI to user |
| `AgentRegistry` | Agent, Tools | app.py |
| `Agent` | Tools, LLM | AgentRegistry |
| `SearchTool` | VectorDB | Agent |
| `MemoryTool` | EnhancedMemoryManager | Agent |
| `MCPTool` | MCPClient | Agent |
| `VectorDB` | Ollama (embeddings), PostgreSQL/JSON | SearchTool |
| `DocumentProcessor` | PyPDF2, python-docx | VectorDB |
| `EnhancedMemoryManager` | JSON file | MemoryTool, UI |
| `MCPClient` | MCP Server (HTTP) | MCPTool |

---

## Embedding Process Detail

```
Text: "Machine learning is a subset of AI"
        │
        ▼
┌─────────────────────────────────────────┐
│   Ollama Embeddings API                 │
│   Model: nomic-embed-text               │
│   Dimension: 768                        │
└─────────────┬───────────────────────────┘
              │
              ▼
Vector: [0.123, -0.456, 0.789, ..., 0.234]
        (768 floating point numbers)
        │
        ▼
┌─────────────────────────────────────────┐
│   PostgreSQL pgvector                   │
│   CREATE TABLE document_embeddings (    │
│     embedding VECTOR(768)               │
│   )                                     │
│                                         │
│   Query: ORDER BY embedding <-> $1      │
│   (Cosine distance operator)            │
└─────────────────────────────────────────┘
```

---

## Security Considerations

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Boundaries                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CodeExecutorTool                                    │  │
│  │  - Restricted builtins                               │  │
│  │  - No file system access                             │  │
│  │  - No network access                                 │  │
│  │  - Timeout limits                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  MCPTool                                             │  │
│  │  - API key authentication                            │  │
│  │  - Rate limiting (MCP server)                        │  │
│  │  - Input validation                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Vector Database                                     │  │
│  │  - Connection string in .env                         │  │
│  │  - Not exposed to agents directly                    │  │
│  │  - SQL injection prevention (parameterized queries)  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

This diagram set provides a comprehensive visual understanding of the AI agent system architecture!
