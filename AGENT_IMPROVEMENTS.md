# AI Agent System Improvements

This document outlines code changes to implement the features discussed in the AI_AGENT_GUIDE.md.

## Summary of Questions Answered

### 1. Conversation History Separation
**Current**: All agents share the same conversation history in `conversations.json`
**Solution**: Implemented tag-based filtering using existing metadata system

### 2. MCP Klavis Integration
**Current**: MCP client exists but not connected to agents
**Solution**: Created MCP tool wrapper and integration guide

### 3. Document Upload and Vector Storage
**Current**: Fully functional but shared across all agents
**Solution**: Document metadata tagging for agent-specific filtering

---

## Implementation Code

### 1. Per-Agent Conversation History

#### File: `src/agents/agent_system.py`

Add agent-aware conversation saving:

```python
# Add after line 229 in agent_system.py

def save_conversation(self, memory_manager, title: str = None):
    """Save current conversation with agent metadata"""
    if not self.conversation_history:
        return None
    
    return memory_manager.save_conversation(
        messages=self.conversation_history,
        title=title or f"{self.config.name} conversation",
        tags=[self.config.name],  # Tag with agent name
        metadata={
            "agent_name": self.config.name,
            "agent_temperature": self.config.temperature,
            "tools_used": list(self.tools.keys())
        }
    )

def load_conversation(self, memory_manager, conversation_id: str):
    """Load a specific conversation into this agent"""
    conversation = memory_manager.get_conversation(conversation_id)
    if conversation:
        self.conversation_history = conversation.get("messages", [])
        return True
    return False

def get_agent_conversations(self, memory_manager, limit: int = 10):
    """Get conversations specific to this agent"""
    return memory_manager.load_conversations(
        tags=[self.config.name],
        limit=limit
    )
```

#### File: `src/app.py`

Update the save conversation logic (around line 200):

```python
# Replace existing save conversation block with:

if st.session_state.messages and st.button("💾 Save Conversation"):
    # Get current agent
    current_agent = self.agent_registry.get(st.session_state.current_agent)
    
    # Save with agent metadata
    conv_id = self.memory.save_conversation(
        messages=st.session_state.messages,
        title=st.session_state.messages[0]['content'][:50] if st.session_state.messages else "Conversation",
        tags=[st.session_state.current_agent],  # Tag with agent name
        metadata={
            "agent_name": st.session_state.current_agent,
            "model_used": st.session_state.current_model,
            "provider": st.session_state.provider
        }
    )
    st.session_state.current_conversation_id = conv_id
    st.success(f"Saved as {st.session_state.current_agent} conversation!")

# Add filter for agent-specific conversations in sidebar
st.divider()
st.subheader("Agent Conversations")
filter_by_agent = st.checkbox("Show only current agent", value=True)

if filter_by_agent:
    agent_convs = self.memory.load_conversations(
        tags=[st.session_state.current_agent],
        limit=5
    )
    if agent_convs:
        st.write(f"{len(agent_convs)} {st.session_state.current_agent} conversations")
```

---

### 2. MCP Tool Integration

#### File: `src/agents/agent_system.py`

Add after the `MemoryTool` class (after line 144):

```python
class MCPTool(Tool):
    """Tool for accessing MCP (Model Context Protocol) services"""
    
    def __init__(self, mcp_client, tool_name: str, tool_description: str):
        self.mcp_client = mcp_client
        self.tool_name = tool_name
        self.tool_description = tool_description
    
    def name(self) -> str:
        return f"mcp_{self.tool_name}"
    
    def description(self) -> str:
        return f"[MCP] {self.tool_description}"
    
    def execute(self, **kwargs) -> Any:
        """Execute MCP tool with parameters"""
        result = self.mcp_client.call_tool(self.tool_name, parameters=kwargs)
        
        if result.get("success"):
            return result.get("data", result)
        else:
            return {"error": result.get("error", "MCP tool execution failed")}


def load_mcp_tools(mcp_client) -> List[Tool]:
    """Load available tools from MCP server"""
    tools = []
    
    try:
        # Get tools from MCP server
        available_tools = mcp_client.list_tools()
        
        for tool_def in available_tools:
            mcp_tool = MCPTool(
                mcp_client,
                tool_def.get('name', 'unknown'),
                tool_def.get('description', 'No description')
            )
            tools.append(mcp_tool)
        
        print(f"Loaded {len(tools)} MCP tools")
        
    except Exception as e:
        print(f"Failed to load MCP tools: {e}")
    
    return tools
```

Update `AgentRegistry.create_default_agents()` (replace method starting at line 250):

```python
def create_default_agents(self, vector_db, memory_manager, mcp_client=None) -> None:
    """Create default set of agents with optional MCP integration"""
    
    # Load MCP tools if available
    mcp_tools = []
    if mcp_client:
        try:
            status = mcp_client.get_status()
            if "OK" in status:
                mcp_tools = load_mcp_tools(mcp_client)
                print(f"MCP integration active: {len(mcp_tools)} tools loaded")
        except Exception as e:
            print(f"MCP integration not available: {e}")
    
    # General Chat Agent
    general_agent = Agent(
        AgentConfig(
            name="General Chat",
            system_prompt="You are a helpful, friendly AI assistant. Engage in natural conversation and help with a wide variety of tasks.",
            temperature=0.7
        )
    )
    self.register(general_agent)
    
    # RAG Assistant with MCP tools
    rag_tools = [SearchTool(vector_db), MemoryTool(memory_manager)]
    if mcp_tools:
        rag_tools.extend(mcp_tools)
    
    rag_agent = Agent(
        AgentConfig(
            name="RAG Assistant",
            system_prompt=(
                "You are a research assistant specialized in finding and synthesizing information from documents. "
                "Always cite which documents or chunks you're referencing. "
                "If information isn't in the documents, clearly state that."
            ),
            temperature=0.5
        ),
        tools=rag_tools
    )
    self.register(rag_agent)
    
    # Code Assistant
    code_agent = Agent(
        AgentConfig(
            name="Coder (DeepSeek style)",
            system_prompt=(
                "You are a meticulous coding assistant inspired by DeepSeek's reasoning approach. "
                "Your process: 1) Understand requirements, 2) Plan the solution, 3) Write clean code, "
                "4) Explain your approach, 5) Suggest tests. "
                "You can execute Python code to verify solutions. "
                "Prefer standard library and minimal dependencies."
            ),
            temperature=0.3
        ),
        tools=[CodeExecutorTool()]
    )
    self.register(code_agent)
    
    # Research Assistant with MCP tools
    research_tools = [SearchTool(vector_db), MemoryTool(memory_manager)]
    if mcp_tools:
        research_tools.extend(mcp_tools)
    
    research_agent = Agent(
        AgentConfig(
            name="Research Assistant",
            system_prompt=(
                "You are a thorough research assistant. Break down complex topics into clear components. "
                "Search through available documents, synthesize information from multiple sources, "
                "and present findings in a structured way. Always cite your sources."
            ),
            temperature=0.4
        ),
        tools=research_tools
    )
    self.register(research_agent)
    
    # MCP Agent (if MCP is available)
    if mcp_tools:
        mcp_agent = Agent(
            AgentConfig(
                name="MCP Assistant",
                system_prompt=(
                    "You are an AI assistant with access to external tools via Model Context Protocol. "
                    "Use available tools to help users with file operations, web searches, and more. "
                    "Always explain what tools you're using and why."
                ),
                temperature=0.6
            ),
            tools=mcp_tools
        )
        self.register(mcp_agent)
```

#### File: `src/app.py`

Update `_setup_agents()` method (around line 55):

```python
def _setup_agents(self):
    """Setup agent registry with tools"""
    # Create default agents with tools and MCP integration
    self.agent_registry.create_default_agents(
        self.vector_db,
        self.memory,
        mcp_client=self.mcp_client  # Pass MCP client
    )
    
    # You can add custom agents here
    # custom_agent = Agent(...)
    # self.agent_registry.register(custom_agent)
```

Add MCP status display in sidebar (around line 120):

```python
# Add in setup_sidebar() method, after theme toggle

st.divider()
st.subheader("🔌 MCP Integration")

# MCP URL configuration
mcp_url = st.text_input(
    "MCP Server URL",
    value=st.session_state.mcp_url,
    key="mcp_url_input"
)

if mcp_url != st.session_state.mcp_url:
    st.session_state.mcp_url = mcp_url
    self.mcp_client.update_url(mcp_url)

# Status check
mcp_status = self.mcp_client.get_status()
if "OK" in mcp_status:
    st.success(f"✅ {mcp_status}")
    
    # Show available tools
    if st.button("🔧 Show MCP Tools"):
        tools = self.mcp_client.list_tools()
        if tools:
            st.write(f"Found {len(tools)} tools:")
            for tool in tools[:5]:  # Show first 5
                st.text(f"• {tool.get('name')}: {tool.get('description', 'N/A')[:50]}...")
        else:
            st.info("No MCP tools available")
else:
    st.warning(f"⚠️ {mcp_status}")
    st.caption("Check that MCP server is running")
```

---

### 3. Per-Agent Document Storage

#### File: `src/vector_db.py`

Update `store_document` method (starting at line 28):

```python
def store_document(self, chunks: List[str], document_name: str, metadata: dict = None):
    """Store document chunks in vector database with metadata"""
    try:
        metadata = metadata or {}
        
        if self._use_postgres:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()
            
            for chunk in chunks:
                embedding = self._embed_text(chunk)
                
                # Store with metadata as JSON
                cursor.execute(
                    "INSERT INTO document_embeddings (document_name, chunk_text, embedding, metadata) "
                    "VALUES (%s, %s, %s, %s)",
                    (document_name, chunk, self._to_pgvector(embedding), json.dumps(metadata))
                )
            
            conn.commit()
            cursor.close()
            conn.close()
        else:
            # JSON fallback store
            records = self._json_load()
            for chunk in chunks:
                embedding = self._embed_text(chunk)
                records.append({
                    "document_name": document_name,
                    "chunk_text": chunk,
                    "embedding": embedding,
                    "metadata": metadata  # Store metadata
                })
            self._json_save(records)
            
    except Exception as e:
        print(f"Error storing document: {e}")
```

Add filtering to `search_similar` (update around line 57):

```python
def search_similar(self, query: str, limit: int = 5, agent_filter: str = None) -> List[str]:
    """Search for similar text chunks using vector similarity with optional agent filtering"""
    try:
        if self._use_postgres:
            conn = psycopg2.connect(self.connection_string)
            cursor = conn.cursor()
            query_emb = self._embed_text(query)
            
            if agent_filter:
                # Filter by agent in metadata
                cursor.execute(
                    """
                    SELECT chunk_text
                    FROM document_embeddings
                    WHERE metadata->>'agent' = %s OR metadata->>'agent' IS NULL
                    ORDER BY embedding <-> %s
                    LIMIT %s
                    """,
                    (agent_filter, self._to_pgvector(query_emb), limit)
                )
            else:
                cursor.execute(
                    """
                    SELECT chunk_text
                    FROM document_embeddings
                    ORDER BY embedding <-> %s
                    LIMIT %s
                    """,
                    (self._to_pgvector(query_emb), limit)
                )
            
            results = [row[0] for row in cursor.fetchall()]
            cursor.close()
            conn.close()
            return results
        else:
            # JSON fallback search with agent filtering
            records = self._json_load()
            if not records:
                return []
            
            # Filter by agent if specified
            if agent_filter:
                records = [
                    r for r in records
                    if r.get("metadata", {}).get("agent") == agent_filter
                    or not r.get("metadata", {}).get("agent")
                ]
            
            query_emb = np.asarray(self._embed_text(query), dtype=np.float32)
            
            def _cosine(a: np.ndarray, b: np.ndarray) -> float:
                denom = (np.linalg.norm(a) * np.linalg.norm(b))
                if denom == 0:
                    return 0.0
                return float(np.dot(a, b) / denom)
            
            scored = []
            for rec in records:
                emb = np.asarray(rec.get("embedding", [0.0] * self.embed_dim), dtype=np.float32)
                score = _cosine(query_emb, emb)
                scored.append((score, rec.get("chunk_text", "")))
            
            scored.sort(key=lambda x: x[0], reverse=True)
            return [text for _, text in scored[:limit]]
            
    except Exception as e:
        print(f"Error searching documents: {e}")
        return []
```

#### Update Database Schema

Add metadata column to `scripts/init_db.sql`:

```sql
-- Update document_embeddings table (if not exists)
ALTER TABLE document_embeddings 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Add index for metadata queries
CREATE INDEX IF NOT EXISTS idx_doc_metadata ON document_embeddings USING GIN (metadata);
```

#### File: `src/agents/agent_system.py`

Update `SearchTool.execute()` to support agent filtering (around line 55):

```python
class SearchTool(Tool):
    """Tool for searching vector database"""
    
    def __init__(self, vector_db, agent_name: str = None):
        self.vector_db = vector_db
        self.agent_name = agent_name  # For filtering
    
    def name(self) -> str:
        return "search_documents"
    
    def description(self) -> str:
        return "Search through uploaded documents for relevant information. Use this when user asks about document content."
    
    def execute(self, query: str, limit: int = 5) -> List[str]:
        # Search with optional agent filtering
        return self.vector_db.search_similar(
            query, 
            limit,
            agent_filter=self.agent_name  # Only search this agent's docs
        )
```

Update agent creation to pass agent name:

```python
# In create_default_agents(), update RAG Assistant creation:

rag_agent = Agent(
    AgentConfig(
        name="RAG Assistant",
        system_prompt=(...),
        temperature=0.5
    ),
    tools=[
        SearchTool(vector_db, agent_name="RAG Assistant"),  # Pass agent name
        MemoryTool(memory_manager)
    ]
)
```

#### File: `src/app.py`

Update document upload to include agent metadata (around line 260):

```python
# In document upload section
if uploaded_file:
    with st.spinner("Processing document..."):
        chunks = self.doc_processor.process_file(
            uploaded_file,
            uploaded_file.name
        )
        
        if chunks:
            # Store with agent metadata
            self.vector_db.store_document(
                chunks,
                uploaded_file.name,
                metadata={
                    "agent": st.session_state.current_agent,
                    "uploaded_by": st.session_state.current_agent,
                    "upload_time": datetime.now().isoformat(),
                    "file_type": uploaded_file.type
                }
            )
            
            st.success(f"✅ Stored {len(chunks)} chunks for {st.session_state.current_agent}")
            st.info(f"📄 Document: {uploaded_file.name}")
        else:
            st.error("Failed to process document")
```

---

## Testing the Improvements

### 1. Test Per-Agent Conversations

```python
# In Python shell or notebook
from src.ui.conversation_manager import EnhancedMemoryManager

memory = EnhancedMemoryManager()

# Save conversation for specific agent
conv_id = memory.save_conversation(
    messages=[{"role": "user", "content": "Hello"}],
    tags=["RAG Assistant"],
    metadata={"agent_name": "RAG Assistant"}
)

# Load only RAG Assistant conversations
rag_convs = memory.load_conversations(tags=["RAG Assistant"])
print(f"Found {len(rag_convs)} RAG Assistant conversations")
```

### 2. Test MCP Integration

```bash
# 1. Start MCP server (example)
docker run -d -p 8080:8080 klavis/mcp-server

# 2. In app, check sidebar for MCP status
# Should show "✅ OK (http://localhost:8080)"

# 3. Click "Show MCP Tools" to see available tools

# 4. Select "MCP Assistant" agent and try using tools
```

### 3. Test Agent-Specific Documents

```python
# Upload document as "RAG Assistant"
# Then switch to "General Chat" and upload another document
# Search should only return relevant documents per agent

# In Python:
from src.vector_db import VectorDB

db = VectorDB()

# Search without filter (all documents)
all_results = db.search_similar("test query", limit=5)

# Search with agent filter
rag_results = db.search_similar("test query", limit=5, agent_filter="RAG Assistant")
```

---

## Migration Script

To migrate existing data to the new schema:

```python
# migration_script.py

import json
import os
from src.ui.conversation_manager import EnhancedMemoryManager

def migrate_conversations():
    """Add agent tags to existing conversations"""
    memory = EnhancedMemoryManager()
    data = memory._load_data()
    
    for conv in data.get("conversations", []):
        # If no tags, add default tag
        if not conv.get("tags"):
            conv["tags"] = ["General Chat"]  # Default agent
        
        # Ensure metadata exists
        if "metadata" not in conv:
            conv["metadata"] = {}
    
    memory._save_data(data)
    print(f"Migrated {len(data.get('conversations', []))} conversations")

if __name__ == "__main__":
    migrate_conversations()
```

Run with:
```bash
cd /workspace
python migration_script.py
```

---

## Environment Setup for MCP

Add to `.env`:

```bash
# MCP Configuration
MCP_URL=http://localhost:8080
MCP_API_KEY=your_optional_api_key_here
MCP_TIMEOUT=10

# Enable MCP features
ENABLE_MCP=true
```

Add to `docker-compose.yml` (optional MCP server):

```yaml
services:
  # ... existing services ...
  
  mcp-server:
    image: klavis/mcp-server:latest
    container_name: mcp-server
    ports:
      - "8080:8080"
    environment:
      - MCP_PORT=8080
      - MCP_LOG_LEVEL=info
    restart: unless-stopped
    networks:
      - ai-network
```

---

## Documentation Updates

The complete guide has been created at:
- **Main Guide**: `/workspace/docs/AI_AGENT_GUIDE.md`
- **Implementation**: `/workspace/AGENT_IMPROVEMENTS.md` (this file)

---

## Next Steps

1. **Apply the code changes** from this document to the respective files
2. **Run migration script** if you have existing conversations
3. **Update database schema** if using PostgreSQL
4. **Configure MCP server** if you want to use MCP integration
5. **Test each feature** using the test scripts provided
6. **Update UI** to show agent-specific filters

---

## Summary

✅ **Conversation History**: Now supports per-agent filtering via tags  
✅ **MCP Integration**: Full integration with dynamic tool loading  
✅ **Document Storage**: Agent-specific document tagging and filtering  

All changes are backward compatible with existing data!
