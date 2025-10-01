# MCP Klavis Setup Guide - Complete Instructions

**Purpose**: Step-by-step guide to setup and integrate MCP Klavis with your AI agents

**Last Updated**: October 1, 2025

---

## 📋 What You Get

This guide provides **two ways** to setup MCP Klavis:

1. **🚀 Automated Setup** (Recommended) - Run a script, everything is done
2. **📝 Manual Setup** - Step-by-step commands if you prefer control

**Both methods are fully documented below.**

---

## 🎯 Quick Summary

### What is MCP Klavis?

**MCP (Model Context Protocol)** is a standardized interface that allows AI agents to access external tools and resources reliably.

Think of it as a "plugin system" for AI agents that provides:
- 🔍 Web search
- 📁 File operations (read/write)
- 🗄️ Database queries
- 🌐 HTTP/API requests
- 🔧 Custom tools

### What This Setup Does

1. ✅ Installs MCP server (Docker container)
2. ✅ Configures environment variables
3. ✅ Integrates MCP tools with AI agents
4. ✅ Verifies everything works
5. ✅ Creates "MCP Assistant" agent

**Time**: 5-10 minutes (automated) or 15-20 minutes (manual)

---

## 🚀 Method 1: Automated Setup (Recommended)

### Prerequisites

- Docker installed and running
- Project running (`docker compose up -d`)
- Terminal access to the project directory

### Step 1: Run Setup Script

```bash
# From project root
./scripts/setup_mcp.sh
```

**What it does**:
1. Checks Docker availability
2. Pulls and runs MCP server container
3. Configures `.env` file
4. Tests MCP connection
5. Offers to run code integration

**Output**:
```
========================================
  MCP Klavis Setup for AI Agents
========================================

[INFO] Step 1: Checking Docker availability...
[✓] Docker is available and running

[INFO] Step 2: Checking for existing MCP server...
[INFO] Step 3: Setting up MCP server container...
[✓] MCP server container started

[INFO] Step 4: Waiting for MCP server to be ready...
[✓] MCP server is ready!

[INFO] Step 5: Configuring environment variables...
[✓] Environment variables configured

[INFO] Step 6: Testing MCP connection...
[✓] MCP server is responding

[INFO] Step 7: Checking available MCP tools...
[✓] Found 5 MCP tools available

[INFO] Step 8: Code integration...
Run automatic integration now? (y/N):
```

### Step 2: Run Code Integration (if prompted)

If you answered "y" to code integration, the script will automatically apply code changes.

If you skipped it, run manually:

```bash
./scripts/integrate_mcp_code.sh
```

**What it does**:
1. Creates backups of existing code
2. Adds `MCPTool` class to agent system
3. Updates agents to load MCP tools
4. Modifies app.py to pass MCP client
5. Verifies all changes

**Output**:
```
========================================
  MCP Integration Complete!
========================================

Changes applied:
  ✓ Added MCPTool class to src/agents/agent_system.py
  ✓ Added load_mcp_tools function
  ✓ Updated create_default_agents to accept mcp_client
  ✓ Updated app.py to pass mcp_client

Backups saved in: backups/mcp_integration_20251001_123456
```

### Step 3: Restart Application

```bash
docker compose restart streamlit-app
```

### Step 4: Verify in UI

1. Open: http://localhost:8501
2. Check sidebar for "MCP Integration" section
3. Should show: ✅ OK (http://localhost:8080)
4. Select "MCP Assistant" agent from dropdown
5. Try asking: "Search the web for Python tutorials"

**Done!** ✅ MCP is integrated and ready to use.

---

## 📝 Method 2: Manual Setup

If you prefer manual control or the automated script doesn't work for your setup.

### Step 1: Run MCP Server

#### Option A: Docker Run (Quickest)

```bash
docker run -d \
  --name mcp-server \
  -p 8080:8080 \
  --restart unless-stopped \
  klavis/mcp-server:latest
```

#### Option B: Add to docker-compose.yml

Edit `docker-compose.yml` and add:

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

Then restart:

```bash
docker compose up -d
```

#### Option C: Build from Source

```bash
git clone https://github.com/Klavis-AI/klavis.git
cd klavis
npm install
npm start  # Runs on http://localhost:8080
```

### Step 2: Configure Environment

Edit `.env` file:

```bash
# Add these lines
MCP_URL=http://localhost:8080
ENABLE_MCP=true
```

If `.env` doesn't exist:

```bash
cat >> .env << 'EOF'

# MCP Configuration
MCP_URL=http://localhost:8080
ENABLE_MCP=true
EOF
```

### Step 3: Verify MCP Server

Test the connection:

```bash
# Health check
curl http://localhost:8080/health

# List available tools
curl http://localhost:8080/api/tools

# Get server info
curl http://localhost:8080/api/info
```

Expected response:
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

### Step 4: Integrate MCP with Agents

#### 4a. Add MCPTool Class

Edit `src/agents/agent_system.py` and add after the `MemoryTool` class (around line 145):

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

#### 4b. Update create_default_agents Method

Still in `src/agents/agent_system.py`, find the `create_default_agents` method (around line 250) and update:

**Change from**:
```python
def create_default_agents(self, vector_db, memory_manager) -> None:
    """Create default set of agents"""
```

**To**:
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
```

Then update the RAG Assistant creation:

**Change from**:
```python
rag_agent = Agent(
    AgentConfig(
        name="RAG Assistant",
        system_prompt=(...),
        temperature=0.5
    ),
    tools=[SearchTool(vector_db), MemoryTool(memory_manager)]
)
```

**To**:
```python
# RAG Assistant with MCP tools
rag_tools = [SearchTool(vector_db), MemoryTool(memory_manager)]
if mcp_tools:
    rag_tools.extend(mcp_tools)

rag_agent = Agent(
    AgentConfig(
        name="RAG Assistant",
        system_prompt=(...),
        temperature=0.5
    ),
    tools=rag_tools
)
```

Add at the end of the method (before the closing):

```python
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

#### 4c. Update app.py

Edit `src/app.py` and find the `_setup_agents` method (around line 55):

**Change from**:
```python
def _setup_agents(self):
    """Setup agent registry with tools"""
    self.agent_registry.create_default_agents(
        self.vector_db,
        self.memory
    )
```

**To**:
```python
def _setup_agents(self):
    """Setup agent registry with tools"""
    self.agent_registry.create_default_agents(
        self.vector_db,
        self.memory,
        mcp_client=self.mcp_client  # Pass MCP client
    )
```

### Step 5: Add MCP Status Display (Optional)

In `src/app.py`, find the `setup_sidebar` method and add MCP status display:

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

### Step 6: Restart Application

```bash
docker compose restart streamlit-app
```

### Step 7: Verify

```bash
# Check MCP container
docker ps | grep mcp-server

# Check logs
docker logs mcp-server

# Test endpoint
curl http://localhost:8080/health
```

In the UI:
1. Open http://localhost:8501
2. Check sidebar for "MCP Integration"
3. Should show ✅ OK status
4. Agent dropdown should include "MCP Assistant"

**Done!** ✅

---

## 🔧 Verification & Testing

### Quick Verification Checklist

- [ ] MCP container is running: `docker ps | grep mcp-server`
- [ ] Health endpoint works: `curl http://localhost:8080/health`
- [ ] Tools endpoint works: `curl http://localhost:8080/api/tools`
- [ ] `.env` has `MCP_URL` configured
- [ ] `MCPTool` class exists in `agent_system.py`
- [ ] App.py passes `mcp_client` to agents
- [ ] UI shows MCP status in sidebar
- [ ] "MCP Assistant" agent is available

### Test MCP Integration

#### Test 1: Check MCP Status

```bash
curl http://localhost:8080/health
```

Expected: `{"status":"ok"}`

#### Test 2: List Available Tools

```bash
curl http://localhost:8080/api/tools | jq
```

Expected: JSON array of tools

#### Test 3: UI Verification

1. Open http://localhost:8501
2. Go to sidebar
3. Find "MCP Integration" section
4. Should show: ✅ OK (http://localhost:8080)
5. Click "Show MCP Tools"
6. Should display list of available tools

#### Test 4: Use MCP Assistant

1. Select "MCP Assistant" from agent dropdown
2. Ask: "What tools do you have access to?"
3. Agent should list MCP tools
4. Try: "Search the web for Python tutorials" (if web_search tool is available)

---

## 🐛 Troubleshooting

### Issue: MCP Container Won't Start

**Symptoms**: Container exits immediately or won't start

**Solution**:
```bash
# Check logs
docker logs mcp-server

# Remove and recreate
docker rm -f mcp-server
./scripts/setup_mcp.sh

# Or try building from source
git clone https://github.com/Klavis-AI/klavis.git
cd klavis
npm install
npm start
```

### Issue: Health Endpoint Returns 404

**Symptoms**: `curl http://localhost:8080/health` returns 404

**Possible causes**:
1. Wrong port - check if MCP is on different port
2. Server not fully started - wait 10 seconds and retry
3. Different health endpoint path

**Solution**:
```bash
# Check which ports the container is using
docker port mcp-server

# Try different endpoints
curl http://localhost:8080/
curl http://localhost:8080/api/health
curl http://localhost:8080/status

# Check container logs
docker logs mcp-server
```

### Issue: "MCP Assistant" Agent Not Appearing

**Symptoms**: Agent dropdown doesn't show MCP Assistant

**Possible causes**:
1. MCP server not running
2. Code integration not applied
3. App not restarted after changes

**Solution**:
```bash
# 1. Verify MCP server
curl http://localhost:8080/health

# 2. Check if code changes were applied
grep -n "class MCPTool" src/agents/agent_system.py

# 3. Restart app
docker compose restart streamlit-app

# 4. Check logs for MCP loading
docker compose logs streamlit-app | grep MCP
```

### Issue: MCP Tools Not Loading

**Symptoms**: MCP server running but no tools available

**Solution**:
```bash
# Check if MCP server has tools
curl http://localhost:8080/api/tools

# If empty, MCP server might need configuration
# Check MCP server documentation for adding tools
```

### Issue: Import Errors After Code Changes

**Symptoms**: App crashes with import errors

**Solution**:
```bash
# Restore from backup
BACKUP_DIR=$(ls -td backups/mcp_integration_* | head -1)
cp $BACKUP_DIR/agent_system.py src/agents/
cp $BACKUP_DIR/app.py src/

# Restart
docker compose restart streamlit-app

# Re-run integration with debug
bash -x scripts/integrate_mcp_code.sh
```

### Issue: Port 8080 Already in Use

**Symptoms**: Cannot start MCP on port 8080

**Solution**:
```bash
# Option 1: Use different port
MCP_PORT=8081 ./scripts/setup_mcp.sh

# Update .env
echo "MCP_URL=http://localhost:8081" >> .env

# Option 2: Stop conflicting service
# Find what's using port 8080
sudo lsof -i :8080
# or
sudo netstat -tlnp | grep 8080

# Stop the service
sudo kill <PID>
```

---

## 🔄 Rollback / Uninstall

### Rollback Code Changes

```bash
# Find backup directory
ls -l backups/

# Restore from backup
BACKUP_DIR="backups/mcp_integration_YYYYMMDD_HHMMSS"
cp $BACKUP_DIR/agent_system.py src/agents/
cp $BACKUP_DIR/app.py src/

# Restart
docker compose restart streamlit-app
```

### Remove MCP Server

```bash
# Stop and remove container
docker stop mcp-server
docker rm mcp-server

# Remove from docker-compose.yml if added
# (edit manually)

# Remove from .env
sed -i '/MCP_URL/d' .env
sed -i '/ENABLE_MCP/d' .env
```

### Complete Cleanup

```bash
# Remove everything
docker rm -f mcp-server
docker rmi klavis/mcp-server:latest
sed -i '/MCP/d' .env
git checkout src/agents/agent_system.py src/app.py
docker compose restart streamlit-app
```

---

## 📚 Additional Resources

### Documentation
- **Complete guide**: `docs/AI_AGENT_GUIDE.md` - Section 2
- **Implementation details**: `AGENT_IMPROVEMENTS.md` - Section 2
- **Quick reference**: `QUICK_REFERENCE.md`
- **Architecture**: `docs/AGENT_ARCHITECTURE_DIAGRAM.md` - Diagram 5

### MCP Resources
- **MCP GitHub**: https://github.com/Klavis-AI/klavis
- **MCP Protocol Spec**: https://github.com/Klavis-AI/klavis/docs/protocol
- **MCP Tools Documentation**: https://github.com/Klavis-AI/klavis/docs/tools

### Scripts Created
- `scripts/setup_mcp.sh` - Automated setup
- `scripts/integrate_mcp_code.sh` - Code integration

---

## 💡 Tips & Best Practices

### Tip 1: Check MCP Server Logs

```bash
# Follow logs in real-time
docker logs -f mcp-server

# Last 100 lines
docker logs --tail 100 mcp-server

# Save logs to file
docker logs mcp-server > mcp_logs.txt
```

### Tip 2: Test MCP Tools Individually

```bash
# Test a specific tool
curl -X POST http://localhost:8080/api/tools/execute \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "web_search",
    "parameters": {"query": "test"}
  }'
```

### Tip 3: Use MCP in Development

Set `MCP_LOG_LEVEL=debug` for more verbose logging:

```bash
docker run -d \
  --name mcp-server \
  -p 8080:8080 \
  -e MCP_LOG_LEVEL=debug \
  klavis/mcp-server:latest
```

### Tip 4: Create Custom MCP Tools

MCP supports custom tools. Check MCP documentation for:
- Tool definition format
- Parameter schemas
- Return value formats

---

## ✅ Success Criteria

You know MCP is setup correctly when:

1. ✅ `curl http://localhost:8080/health` returns OK
2. ✅ `docker ps` shows mcp-server running
3. ✅ UI sidebar shows "✅ OK (http://localhost:8080)"
4. ✅ Agent dropdown includes "MCP Assistant"
5. ✅ Clicking "Show MCP Tools" displays available tools
6. ✅ MCP Assistant can describe its available tools
7. ✅ No errors in `docker compose logs streamlit-app`

---

## 🚀 Next Steps After Setup

1. **Explore MCP Tools**:
   - Try different MCP tools
   - Check tool capabilities
   - Read tool documentation

2. **Create Custom Agents**:
   - Combine MCP tools with other tools
   - Create specialized agents
   - Customize system prompts

3. **Develop Custom Tools**:
   - Write your own MCP tools
   - Integrate with internal APIs
   - Add business-specific logic

4. **Monitor & Optimize**:
   - Check MCP performance
   - Monitor tool usage
   - Optimize tool selection

---

## 📊 Summary

| Method | Time | Difficulty | Recommended For |
|--------|------|-----------|-----------------|
| **Automated** | 5-10 min | ⭐ Easy | Everyone |
| **Manual** | 15-20 min | ⭐⭐ Medium | Advanced users, Custom setups |

**Both methods achieve the same result**: MCP Klavis integrated and ready to use!

---

**Setup complete?** Head to `docs/AI_AGENT_GUIDE.md` Section 2 for advanced MCP usage!

---

*Last Updated: October 1, 2025*  
*Scripts: `scripts/setup_mcp.sh`, `scripts/integrate_mcp_code.sh`*
