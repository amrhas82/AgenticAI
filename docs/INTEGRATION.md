# Integration Guide

Quick reference for integrating new features into your AI Agent Playground.

## API Key Management

### Adding API Key Protection to Routes

```python
from api_key_manager import require_api_key, APIKeyManager

# Protect specific functions
@require_api_key("documents")
def upload_document_endpoint():
    # This endpoint now requires a valid API key with 'documents' permission
    pass

# Manage keys programmatically
manager = APIKeyManager()

# Create a new key
api_key = manager.create_key(
    name="Mobile App",
    description="Access from mobile application",
    permissions={
        "chat": True,
        "documents": True,
        "memory": False
    },
    expires_days=90
)
print(f"New API key (save this!): {api_key}")

# List all keys
keys = manager.list_keys()
for key_info in keys:
    print(f"{key_info['name']}: Active={key_info['is_active']}")

# Revoke a key
manager.revoke_key("Mobile App")
```

### Using API Keys in Streamlit

```python
import streamlit as st
from api_key_manager import APIKeyManager

# In sidebar or settings
api_key = st.text_input("API Key", type="password")
if api_key:
    st.session_state['api_key'] = api_key
    
    # Verify
    manager = APIKeyManager()
    verification = manager.verify_key(api_key)
    
    if verification['valid']:
        st.success(f"✅ Authenticated as: {verification['name']}")
        # Show permissions
        perms = verification['permissions']
        st.write("Permissions:", perms)
    else:
        st.error(f"❌ {verification.get('reason', 'Invalid key')}")
```

## Enhanced MCP Integration

### Using MCP Tools in Agents

```python
from mcp_client import MCPClient
from agents.agent_system import Agent, Tool, AgentConfig

class MCPTool(Tool):
    """Wrap MCP tools for agent use"""
    
    def __init__(self, mcp_client: MCPClient, tool_name: str):
        self.mcp = mcp_client
        self.tool_name = tool_name
        self._info = None
    
    def name(self) -> str:
        return self.tool_name
    
    def description(self) -> str:
        if not self._info:
            tools = self.mcp.list_tools()
            for t in tools:
                if t['name'] == self.tool_name:
                    self._info = t
                    break
        return self._info.get('description', '') if self._info else ''
    
    def execute(self, **kwargs):
        return self.mcp.call_tool(self.tool_name, kwargs)

# Create agent with MCP tools
mcp = MCPClient()
mcp_tools_list = mcp.list_tools()

agent = Agent(
    AgentConfig(
        name="MCP Agent",
        system_prompt="You can use external tools via MCP"
    ),
    tools=[MCPTool(mcp, tool['name']) for tool in mcp_tools_list]
)
```

### Direct MCP Usage

```python
from mcp_client import MCPClient

mcp = MCPClient("http://localhost:8080")

# Check connection
status = mcp.get_status()
print(status)

# List available tools
tools = mcp.list_tools()
for tool in tools:
    print(f"- {tool['name']}: {tool['description']}")

# Execute a tool
result = mcp.call_tool(
    "web_search",
    {"query": "Python best practices", "limit": 5}
)
print(result)

# Access resources
resources = mcp.list_resources()
content = mcp.read_resource("file:///path/to/document.txt")

# Use prompts
prompts = mcp.get_prompts()
rendered = mcp.execute_prompt(
    "code_review",
    {"code": "def hello(): print('world')"}
)
```

## Document Processing Enhancement

### Using the New DocumentProcessor

```python
from document_processor import DocumentProcessor

processor = DocumentProcessor(
    chunk_size=1000,
    chunk_overlap=200
)

# Automatic format detection
chunks = processor.process_file(uploaded_file)

# Explicit format
chunks = processor.process_pdf(pdf_file)
chunks = processor.process_docx(word_file)
chunks = processor.process_text(text_file)

# Extract metadata
metadata = processor.extract_metadata(uploaded_file)
print(f"Pages: {metadata['page_count']}")
print(f"Words: {metadata['word_count']}")
```

### Updating Existing Code

If you're using the old `PDFProcessor`, it still works as an alias:

```python
# Old code (still works)
from pdf_processor import PDFProcessor
processor = PDFProcessor()

# New code (recommended)
from document_processor import DocumentProcessor
processor = DocumentProcessor()
```

## Vector Database with Metadata

### Storing Documents with Rich Metadata

```python
from database.enhanced_vector_db import EnhancedVectorDB

vector_db = EnhancedVectorDB()

# Store with metadata
vector_db.store_document(
    chunks=chunks,
    document_name="research_paper.pdf",
    metadata={
        "author": "John Doe",
        "category": "research",
        "year": 2025,
        "tags": ["AI", "ML"],
        "custom_field": "custom_value"
    }
)

# Search with filters
results = vector_db.search_similar(
    query="machine learning techniques",
    limit=5,
    filters={"category": "research", "year": 2025},
    rerank=True
)

for result in results:
    print(f"Score: {result['score']:.3f}")
    print(f"Text: {result['chunk_text'][:100]}...")
    print(f"Metadata: {result['metadata']}")
```

### Document Management

```python
# Get statistics
stats = vector_db.get_document_stats()
print(f"Total documents: {stats['total_documents']}")
print(f"Total chunks: {stats['total_chunks']}")

# List all documents
documents = vector_db.list_documents()
for doc in documents:
    print(f"{doc['name']}: {doc['chunks']} chunks")

# Delete a document
vector_db.delete_document("old_document.pdf")
```

## Enhanced Memory System

### Using Enhanced Memory in UI

```python
from ui.conversation_manager import EnhancedMemoryManager, ConversationManagerUI
import streamlit as st

# Initialize
memory = EnhancedMemoryManager()
conv_ui = ConversationManagerUI(memory)

# In your app
if st.session_state.page == "Conversations":
    conv_ui.render_conversation_history()

# In sidebar for quick access
with st.sidebar:
    conv_ui.render_sidebar_quick_access()

# Save conversation with metadata
conv_id = memory.save_conversation(
    messages=st.session_state.messages,
    title="Discussion about RAG",
    tags=["rag", "vector-db", "ai"]
)

# Search conversations
results = memory.search_conversations("vector database")
for conv in results:
    st.write(f"Found: {conv['title']}")
```

### Export Conversations

```python
from ui.conversation_manager import EnhancedMemoryManager

memory = EnhancedMemoryManager()

# Export as JSON
json_data = memory.export_conversation(conv_id, format="json")

# Export as Markdown
md_data = memory.export_conversation(conv_id, format="markdown")

# Export as plain text
txt_data = memory.export_conversation(conv_id, format="txt")

# In Streamlit
st.download_button(
    "Download Conversation",
    data=md_data,
    file_name=f"conversation_{conv_id}.md",
    mime="text/markdown"
)
```

## Configuration Management

### Using ConfigManager

```python
from utils.config_manager import ConfigManager, ConfigUI

# Initialize
config_manager = ConfigManager()

# Access settings
ollama_host = config_manager.system_config.ollama_host
theme = config_manager.system_config.theme

# Get model-specific config
model_config = config_manager.get_model_config("llama3")
temperature = model_config.temperature
max_tokens = model_config.max_tokens

# Update configuration
model_config.temperature = 0.8
config_manager.update_model_config("llama3", model_config)

# Save to disk
config_manager.save_config()

# In Streamlit UI
config_ui = ConfigUI(config_manager)
config_ui.render_settings_page()
```

## Complete Integration Example

Here's a full example integrating all features:

```python
import streamlit as st
from ollama_client import OllamaClient
from document_processor import DocumentProcessor
from database.enhanced_vector_db import EnhancedVectorDB
from ui.conversation_manager import EnhancedMemoryManager
from mcp_client import MCPClient
from api_key_manager import APIKeyManager, require_api_key
from agents.agent_system import AgentRegistry

class EnhancedAIApp:
    def __init__(self):
        # Core components
        self.ollama = OllamaClient()
        self.doc_processor = DocumentProcessor()
        self.vector_db = EnhancedVectorDB()
        self.memory = EnhancedMemoryManager()
        self.mcp = MCPClient()
        self.api_manager = APIKeyManager()
        
        # Agents
        self.agent_registry = AgentRegistry()
        self.agent_registry.create_default_agents(
            self.vector_db,
            self.memory
        )
    
    @require_api_key("chat")
    def handle_chat(self, message: str):
        """Protected chat endpoint"""
        agent = self.agent_registry.get("RAG Assistant")
        
        # Get context from vector DB
        context = self.vector_db.search_similar(
            message,
            limit=3,
            rerank=True
        )
        
        # Generate response
        result = agent.process_message(message, self.ollama)
        
        # Save to memory
        self.memory.save_conversation(
            messages=[
                {"role": "user", "content": message},
                {"role": "assistant", "content": result["response"]}
            ],
            tags=["auto-save"]
        )
        
        return result["response"]
    
    @require_api_key("documents")
    def handle_upload(self, file):
        """Protected document upload"""
        # Process document
        chunks = self.doc_processor.process_file(file)
        metadata = self.doc_processor.extract_metadata(file)
        
        # Store in vector DB
        self.vector_db.store_document(
            chunks,
            file.name,
            metadata
        )
        
        return len(chunks)
    
    def use_mcp_tool(self, tool_name: str, params: dict):
        """Use MCP tool"""
        result = self.mcp.call_tool(tool_name, params)
        return result

# Usage
app = EnhancedAIApp()

# In Streamlit
st.title("Enhanced AI Playground")

# API Key input
api_key = st.text_input("API Key", type="password")
if api_key:
    st.session_state['api_key'] = api_key

# Chat
if prompt := st.chat_input("Message"):
    try:
        response = app.handle_chat(prompt)
        st.write(response)
    except Exception as e:
        st.error(f"Error: {e}")

# Upload
uploaded_file = st.file_uploader("Upload Document")
if uploaded_file:
    try:
        chunks = app.handle_upload(uploaded_file)
        st.success(f"Uploaded: {chunks} chunks")
    except Exception as e:
        st.error(f"Error: {e}")
```

## Environment Setup Checklist

Make sure your `.env` has all new variables:

```bash
# Copy example
cp .env.example .env

# Required for new features:
MCP_URL=http://localhost:8080
MCP_API_KEY=                    # Optional
ENABLE_API_AUTH=false           # Set to true for production
MASTER_API_KEY=                 # Set for admin access
API_KEYS_JSON_PATH=data/memory/api_keys.json
```

## Database Migration

Run this to update your PostgreSQL schema:

```bash
# Connect to database
docker exec -it <postgres-container> psql -U ai_user -d ai_playground

# Or locally
psql -h localhost -U ai_user -d ai_playground

# Then run:
\i scripts/init_db.sql
```

This will add:
- `metadata` column to `document_embeddings`
- `api_keys` table
- Necessary indexes

## Testing Integration

```python
# Test script
def test_integration():
    # Test MCP
    mcp = MCPClient()
    assert "OK" in mcp.get_status() or "Not reachable" in mcp.get_status()
    
    # Test Document Processing
    processor = DocumentProcessor()
    chunks = processor.process_text("Test document content here")
    assert len(chunks) > 0
    
    # Test Vector DB
    vector_db = EnhancedVectorDB()
    vector_db.store_document(chunks, "test.txt", {"test": True})
    results = vector_db.search_similar("test", limit=1)
    assert len(results) > 0
    
    # Test Memory
    memory = EnhancedMemoryManager()
    conv_id = memory.save_conversation(
        [{"role": "user", "content": "test"}],
        title="Test"
    )
    assert conv_id is not None
    
    # Test API Keys
    api_manager = APIKeyManager()
    key = api_manager.create_key("Test Key")
    if key:
        verification = api_manager.verify_key(key)
        assert verification['valid']
        api_manager.revoke_key("Test Key")
    
    print("✅ All tests passed!")

if __name__ == "__main__":
    test_integration()
```

Save this as `test_integration.py` and run:
```bash
python test_integration.py
```
