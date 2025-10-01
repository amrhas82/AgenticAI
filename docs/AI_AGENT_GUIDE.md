# AI Agent System Guide

This guide answers key questions about the AI agent architecture in this playground system.

## Table of Contents
1. [Do All AI Agents Have Different JSON Conversation History?](#conversation-history)
2. [How to Setup MCP Klavis for AI Agents](#mcp-setup)
3. [Do AI Agents Accept Document Upload and Store on Vector DB?](#document-upload)

---

## 1. Do All AI Agents Have Different JSON Conversation History? {#conversation-history}

### Short Answer
**No, all agents currently share the same conversation history** in the current implementation.

### Detailed Explanation

#### Current Architecture
The system uses a **shared conversation memory** approach:

- **Location**: `data/memory/conversations.json`
- **Manager**: `EnhancedMemoryManager` class in `src/ui/conversation_manager.py`
- **Scope**: Global across all agents in the same session

```python
# From src/app.py (lines 44-47)
self.memory = EnhancedMemoryManager()  # Single shared instance
self.conversation_ui = ConversationManagerUI(self.memory)
```

#### How It Works

1. **Session-Level Storage**: 
   - Conversations are stored in `st.session_state.messages`
   - When saved, they go to the shared `conversations.json` file
   - Each conversation has a unique ID, but not tied to specific agents

2. **Agent-Specific In-Memory History**:
   - Each `Agent` instance has its own `conversation_history` list (line 153 in `agent_system.py`)
   - This is **temporary** and only lasts during the agent's lifecycle
   - Not persisted separately

```python
# From src/agents/agent_system.py
class Agent:
    def __init__(self, config: AgentConfig, tools: Optional[List[Tool]] = None):
        self.config = config
        self.tools = {tool.name(): tool for tool in (tools or [])}
        self.conversation_history: List[Dict] = []  # Temporary, per-agent
```

#### Current Conversation Flow

```
User Message
    ↓
st.session_state.messages (shared UI state)
    ↓
Agent.process_message() → agent.conversation_history (temporary)
    ↓
EnhancedMemoryManager.save_conversation() → conversations.json (shared file)
```

### How to Implement Per-Agent Conversation History

If you want **separate conversation histories for each agent**, here's how:

#### Option 1: Agent-Specific JSON Files

```python
# Modify src/ui/conversation_manager.py
class EnhancedMemoryManager:
    def __init__(self, memory_file: str = "data/memory/conversations.json", agent_name: Optional[str] = None):
        if agent_name:
            # Create agent-specific file
            base_dir = os.path.dirname(memory_file)
            filename = f"conversations_{agent_name.lower().replace(' ', '_')}.json"
            self.memory_file = os.path.join(base_dir, filename)
        else:
            self.memory_file = memory_file
        os.makedirs(os.path.dirname(self.memory_file), exist_ok=True)
```

#### Option 2: Tag-Based Separation (Recommended)

Use the existing tagging system to filter conversations by agent:

```python
# When saving a conversation
conv_id = memory.save_conversation(
    messages=st.session_state.messages,
    title="My conversation",
    tags=["RAG Assistant"],  # Tag with agent name
    metadata={"agent": st.session_state.current_agent}
)

# When loading conversations for specific agent
rag_conversations = memory.load_conversations(tags=["RAG Assistant"])
```

#### Option 3: Database Schema Extension

Add an `agent_id` column to track which agent the conversation belongs to:

```python
# Modify conversation structure
conversation = {
    "id": self._generate_id(),
    "agent_name": agent_name,  # Add this field
    "timestamp": datetime.now().isoformat(),
    "title": title,
    "messages": messages,
    ...
}
```

---

## 2. How to Setup MCP Klavis for AI Agents {#mcp-setup}

### What is MCP Klavis?

**MCP (Model Context Protocol)** by Klavis AI is a standardized interface for AI agents to access tools and resources reliably. Think of it as a plugin system for AI agents.

- **GitHub**: https://github.com/Klavis-AI/klavis
- **Purpose**: Provides tools (file system, web search, databases) via a standard API
- **Implementation**: `src/mcp_client.py`

### Current MCP Integration Status

✅ **Client is implemented** in `src/mcp_client.py`  
❌ **Not yet connected to agents** - agents don't use MCP tools yet  
⚠️ **Requires external MCP server** - you need to run Klavis separately

### Step-by-Step Setup

#### Step 1: Install and Run MCP Klavis Server

```bash
# Option A: Using Docker (Recommended)
docker pull klavis/mcp-server:latest
docker run -d \
  -p 8080:8080 \
  --name mcp-server \
  klavis/mcp-server:latest

# Option B: From Source
git clone https://github.com/Klavis-AI/klavis.git
cd klavis
npm install
npm start  # Runs on http://localhost:8080
```

#### Step 2: Configure MCP URL in the App

The app uses `MCPClient` which can be configured via:

1. **Environment Variable** (in `.env`):
```bash
MCP_URL=http://localhost:8080
MCP_API_KEY=your_api_key_if_required
```

2. **UI Configuration** (Sidebar):
```python
# From src/app.py
st.session_state.mcp_url = "http://localhost:8080"
```

3. **Test Connection**:
```python
mcp_status = self.mcp_client.get_status()
st.info(f"MCP Status: {mcp_status}")
```

#### Step 3: Integrate MCP Tools with Agents

Currently, agents use custom tools (`SearchTool`, `CodeExecutorTool`, etc.). To use MCP tools:

##### Create MCP Tool Wrapper

```python
# Add to src/agents/agent_system.py

class MCPTool(Tool):
    """Wrapper for MCP tools"""
    
    def __init__(self, mcp_client, tool_name: str, tool_description: str):
        self.mcp_client = mcp_client
        self.tool_name = tool_name
        self.tool_description = tool_description
    
    def name(self) -> str:
        return self.tool_name
    
    def description(self) -> str:
        return self.tool_description
    
    def execute(self, **kwargs) -> Any:
        result = self.mcp_client.call_tool(self.tool_name, parameters=kwargs)
        return result
```

##### Load MCP Tools Dynamically

```python
# Modify AgentRegistry.create_default_agents()

def create_default_agents(self, vector_db, memory_manager, mcp_client=None):
    # ... existing agents ...
    
    # Add MCP-enabled agent
    if mcp_client:
        mcp_tools = []
        
        # Get available tools from MCP server
        available_tools = mcp_client.list_tools()
        
        for tool_def in available_tools:
            mcp_tool = MCPTool(
                mcp_client,
                tool_def['name'],
                tool_def['description']
            )
            mcp_tools.append(mcp_tool)
        
        # Create MCP-powered agent
        mcp_agent = Agent(
            AgentConfig(
                name="MCP Assistant",
                system_prompt="You are an AI assistant with access to external tools via MCP.",
                temperature=0.5
            ),
            tools=mcp_tools
        )
        self.register(mcp_agent)
```

##### Update App Initialization

```python
# Modify src/app.py _setup_agents()

def _setup_agents(self):
    """Setup agent registry with tools"""
    # Pass MCP client to agents
    self.agent_registry.create_default_agents(
        self.vector_db,
        self.memory,
        mcp_client=self.mcp_client  # Add this
    )
```

#### Step 4: Verify MCP Integration

Add a test section in the UI:

```python
# In sidebar or settings page
st.subheader("🔌 MCP Integration")
mcp_status = self.mcp_client.get_status()
st.write(f"Status: {mcp_status}")

if st.button("Test MCP"):
    tools = self.mcp_client.list_tools()
    st.write("Available MCP Tools:")
    for tool in tools:
        st.write(f"- {tool['name']}: {tool['description']}")
```

### MCP Features Available

Once configured, agents can use:

1. **Tools**: File operations, web search, API calls
   ```python
   result = mcp_client.call_tool("web_search", {"query": "Python tutorials"})
   ```

2. **Resources**: Access to files, databases
   ```python
   content = mcp_client.read_resource("file:///path/to/document.txt")
   ```

3. **Prompts**: Pre-defined prompt templates
   ```python
   rendered = mcp_client.execute_prompt("summarize", {"text": "..."})
   ```

---

## 3. Do AI Agents Accept Document Upload and Store on Vector DB? {#document-upload}

### Short Answer
**Yes, the system supports document upload with vector storage**, but it's currently **shared across all agents**, not per-agent.

### Supported File Formats

From `src/document_processor.py`:

✅ **PDF** (.pdf) - via PyPDF2  
✅ **Text** (.txt, .md, .markdown)  
✅ **Word** (.docx) - via python-docx  
❌ **Old Word** (.doc) - not supported, convert to .docx first

### How Document Upload Works

#### Architecture Flow

```
User Uploads File (UI)
    ↓
DocumentProcessor.process_file() → Extract text → Split into chunks
    ↓
VectorDB._embed_text() → Create embeddings (via Ollama)
    ↓
VectorDB.store_document() → Store in PostgreSQL (pgvector) OR JSON fallback
    ↓
Available for RAG search by all agents
```

#### Code Implementation

From `src/ui/document_manager.py` and `src/app.py`:

```python
# Upload document
uploaded_file = st.file_uploader("Upload document", type=["pdf", "txt", "md", "docx"])

if uploaded_file:
    # Process document
    chunks = doc_processor.process_file(uploaded_file, uploaded_file.name)
    
    # Store in vector DB
    vector_db.store_document(chunks, document_name=uploaded_file.name)
    
    st.success(f"Stored {len(chunks)} chunks in vector database")
```

### Vector Database Details

#### Storage Backends

The system supports **two storage backends**:

1. **PostgreSQL with pgvector** (Primary)
   - Requires: `DATABASE_URL` environment variable
   - Uses: Postgres + pgvector extension
   - Performance: Fast, production-ready
   - Schema:
   ```sql
   CREATE TABLE document_embeddings (
       id SERIAL PRIMARY KEY,
       document_name TEXT NOT NULL,
       chunk_text TEXT NOT NULL,
       embedding VECTOR(768)  -- Dimension based on EMBED_DIM
   );
   ```

2. **JSON Fallback** (Backup)
   - Location: `data/memory/vector_store.json`
   - Uses: Numpy for cosine similarity
   - Performance: Slower, for development only

From `src/vector_db.py`:

```python
class VectorDB:
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")
        self.embed_model = os.getenv("EMBED_MODEL", "nomic-embed-text")
        self.embed_dim = int(os.getenv("EMBED_DIM", "768"))
        self._use_postgres = bool(self.connection_string) and _HAVE_PSYCOPG2
        self._json_path = os.getenv("VECTOR_JSON_PATH", "data/memory/vector_store.json")
```

#### Embedding Model Configuration

```bash
# In .env file
EMBED_MODEL=nomic-embed-text  # Default embedding model
EMBED_DIM=768                 # Embedding dimension
OLLAMA_HOST=http://localhost:11434
```

### RAG (Retrieval Augmented Generation)

#### How RAG Works with Agents

1. **Agent with SearchTool**:
   ```python
   # From agent_system.py
   class SearchTool(Tool):
       def execute(self, query: str, limit: int = 5) -> List[str]:
           return self.vector_db.search_similar(query, limit)
   ```

2. **RAG-Enabled Agents**:
   - **RAG Assistant**: Has `SearchTool` and `MemoryTool`
   - **Research Assistant**: Has `SearchTool` and `MemoryTool`

3. **Usage Flow**:
   ```
   User: "What does the document say about X?"
       ↓
   Agent detects document query
       ↓
   Agent calls SearchTool with query "X"
       ↓
   VectorDB.search_similar() → Returns top-k relevant chunks
       ↓
   Agent receives chunks → Generates response with context
       ↓
   User receives answer with citations
   ```

#### Manual RAG Example

```python
# Example from examples/rag_example.py

# 1. Upload and process document
chunks = doc_processor.process_file("example.pdf")

# 2. Store in vector DB
vector_db.store_document(chunks, "example.pdf")

# 3. Search for relevant context
query = "What is machine learning?"
results = vector_db.search_similar(query, limit=3)

# 4. Use results in prompt
context = "\n\n".join(results)
prompt = f"Based on this context:\n{context}\n\nAnswer: {query}"

# 5. Generate response
response = ollama.generate_response(prompt, history=[], model="llama2")
```

### Per-Agent Document Isolation

Currently, **all agents share the same vector database**. To implement per-agent document storage:

#### Option 1: Document Metadata Tagging

Add agent metadata when storing documents:

```python
# Modify vector_db.py to support metadata
def store_document(self, chunks: List[str], document_name: str, metadata: Dict = None):
    metadata = metadata or {}
    agent_name = metadata.get("agent", "default")
    
    # Store with agent association
    for chunk in chunks:
        embedding = self._embed_text(chunk)
        cursor.execute(
            "INSERT INTO document_embeddings (document_name, chunk_text, embedding, metadata) "
            "VALUES (%s, %s, %s, %s)",
            (document_name, chunk, embedding, json.dumps(metadata))
        )
```

#### Option 2: Separate Collections/Tables

Create separate vector tables per agent:

```sql
CREATE TABLE rag_assistant_embeddings (...);
CREATE TABLE research_assistant_embeddings (...);
```

#### Option 3: Namespace Prefixing

Prefix document names with agent ID:

```python
# When storing
agent_prefix = f"{agent_name}__"
vector_db.store_document(chunks, f"{agent_prefix}{filename}")

# When searching (in SearchTool)
def execute(self, query: str, limit: int = 5) -> List[str]:
    # Filter by agent
    return self.vector_db.search_similar(
        query, limit,
        filter_prefix=f"{self.agent_name}__"
    )
```

### Document Management UI

The app includes a full document management interface:

```python
# From src/ui/document_manager.py

class DocumentManager:
    def render_document_page(self):
        # Upload section
        uploaded_file = st.file_uploader(...)
        
        # Document list
        documents = self.list_documents()
        
        # Actions: view, search, delete
```

Features:
- 📤 Upload documents (PDF, TXT, MD, DOCX)
- 🗂️ View all uploaded documents
- 🔍 Search within documents
- 🗑️ Delete documents
- 📊 View document statistics

---

## Quick Reference: Agent & Tool Capabilities

| Agent Name | Has Vector Search? | Has Memory Tool? | Has Code Execution? | MCP Ready? |
|------------|-------------------|------------------|---------------------|------------|
| General Chat | ❌ | ❌ | ❌ | ✅ (can add) |
| RAG Assistant | ✅ | ✅ | ❌ | ✅ (can add) |
| Coder (DeepSeek) | ❌ | ❌ | ✅ | ✅ (can add) |
| Research Assistant | ✅ | ✅ | ❌ | ✅ (can add) |

---

## Configuration Summary

### Environment Variables

```bash
# .env file

# Ollama (for LLM and embeddings)
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768

# PostgreSQL (vector storage)
DATABASE_URL=postgresql://ai_user:ai_password@localhost:5432/ai_playground

# MCP Integration
MCP_URL=http://localhost:8080
MCP_API_KEY=optional_api_key

# OpenAI (optional)
OPENAI_API_KEY=sk-...
```

### File Structure

```
data/
├── memory/
│   ├── conversations.json          # All conversation history
│   ├── vector_store.json          # JSON fallback for vectors
│   └── test_conv.json
├── documents/
│   └── example.pdf                # Uploaded documents
└── config/
    └── system_config.json         # System settings

src/
├── agents/
│   └── agent_system.py            # Agent definitions & tools
├── ui/
│   ├── conversation_manager.py    # Conversation management
│   └── document_manager.py        # Document upload UI
├── mcp_client.py                  # MCP integration
├── vector_db.py                   # Vector storage
└── document_processor.py          # File parsing
```

---

## Common Use Cases

### Use Case 1: Chat with Documents

```python
# 1. Select "RAG Assistant" agent
st.session_state.current_agent = "RAG Assistant"

# 2. Upload document via UI
# Go to Documents page → Upload PDF

# 3. Ask questions
# The RAG Assistant will automatically search the vector DB
prompt = "What are the key findings in the document?"
```

### Use Case 2: Create Custom Agent with Tools

```python
from agents.agent_system import Agent, AgentConfig, SearchTool

# Create custom agent
custom_agent = Agent(
    AgentConfig(
        name="My Custom Agent",
        system_prompt="You are a specialized assistant...",
        temperature=0.6
    ),
    tools=[
        SearchTool(vector_db),  # Document search
        MemoryTool(memory_manager),  # Conversation recall
    ]
)

# Register it
agent_registry.register(custom_agent)
```

### Use Case 3: Per-Agent Document Collections

```python
# When uploading for specific agent
agent_name = st.session_state.current_agent

# Add metadata
vector_db.store_document(
    chunks,
    document_name="report.pdf",
    metadata={"agent": agent_name, "uploaded_at": datetime.now().isoformat()}
)

# Filter searches by agent
search_results = vector_db.search_similar(
    query="key findings",
    limit=5,
    agent_filter=agent_name  # Need to implement this filter
)
```

---

## Next Steps

### Immediate Improvements

1. **Implement per-agent conversation storage** using tags or separate files
2. **Connect MCP tools to agents** following the guide above
3. **Add agent metadata to vector storage** for document isolation
4. **Create agent-specific document views** in the UI

### Advanced Features

1. **Agent collaboration**: Allow agents to communicate with each other
2. **Workflow chains**: Create multi-agent pipelines
3. **Custom tool development**: Build domain-specific tools
4. **Persistent agent state**: Save agent state beyond just conversations

---

## Troubleshooting

### Documents Not Being Found in Search

1. Check vector DB is initialized:
   ```bash
   docker compose exec postgres psql -U ai_user -d ai_playground -c "\dt"
   # Should show document_embeddings table
   ```

2. Verify embeddings are being generated:
   ```bash
   curl http://localhost:11434/api/embeddings -d '{
     "model": "nomic-embed-text",
     "prompt": "test"
   }'
   ```

3. Check Ollama is accessible from container:
   ```bash
   docker compose exec streamlit-app curl http://host.docker.internal:11434/api/tags
   ```

### MCP Server Not Connecting

1. Verify MCP server is running:
   ```bash
   curl http://localhost:8080/health
   ```

2. Check firewall rules allow connections

3. Update MCP URL in UI sidebar

### Agent Not Using Tools

1. Ensure agent has tools registered:
   ```python
   agent = agent_registry.get("RAG Assistant")
   print(agent.tools)  # Should show SearchTool, MemoryTool
   ```

2. Check LLM is responding with tool calls (JSON format)

3. Verify tool execution isn't failing silently

---

## References

- **Agent System**: `src/agents/agent_system.py`
- **Memory Manager**: `src/ui/conversation_manager.py`
- **Vector DB**: `src/vector_db.py`
- **MCP Client**: `src/mcp_client.py`
- **Document Processor**: `src/document_processor.py`
- **Main App**: `src/app.py`

---

## Contributing

To extend the agent system:

1. Create new tools by extending the `Tool` base class
2. Register agents in `AgentRegistry.create_default_agents()`
3. Add UI controls in `src/app.py`
4. Update this guide with your changes!

---

**Last Updated**: October 1, 2025  
**Version**: 1.0.0
