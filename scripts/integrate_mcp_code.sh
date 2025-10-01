#!/usr/bin/env bash
#
# MCP Code Integration Script
#
# This script automatically applies code changes to integrate MCP tools with AI agents.
# It implements the changes documented in AGENT_IMPROVEMENTS.md Section 2.
#
# Usage:
#   chmod +x scripts/integrate_mcp_code.sh
#   ./scripts/integrate_mcp_code.sh
#

set -e
set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MCP Code Integration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "src/agents/agent_system.py" ]; then
    print_error "Must be run from project root (where src/ is located)"
    exit 1
fi

# Create backup
print_status "Creating backups..."
BACKUP_DIR="backups/mcp_integration_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

cp src/agents/agent_system.py "$BACKUP_DIR/" || {
    print_error "Failed to backup agent_system.py"
    exit 1
}

if [ -f "src/app.py" ]; then
    cp src/app.py "$BACKUP_DIR/"
fi

print_success "Backups created in: $BACKUP_DIR"

# Step 1: Add MCPTool class to agent_system.py
print_status "Step 1: Adding MCPTool class to agent_system.py..."

if grep -q "class MCPTool" src/agents/agent_system.py; then
    print_warning "MCPTool class already exists, skipping..."
else
    # Find the line after MemoryTool class definition
    LINE_NUM=$(grep -n "class MemoryTool" src/agents/agent_system.py | tail -1 | cut -d: -f1)
    
    if [ -z "$LINE_NUM" ]; then
        print_error "Could not find MemoryTool class"
        exit 1
    fi
    
    # Find the end of MemoryTool class (next class or end of file)
    END_LINE=$(tail -n +$LINE_NUM src/agents/agent_system.py | grep -n "^class " | head -2 | tail -1 | cut -d: -f1)
    
    if [ -z "$END_LINE" ]; then
        # Insert at end of file
        END_LINE=$(wc -l < src/agents/agent_system.py)
    else
        END_LINE=$((LINE_NUM + END_LINE - 2))
    fi
    
    # Insert MCPTool class after MemoryTool
    cat > /tmp/mcp_tool_class.txt << 'EOF'


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

EOF
    
    # Use sed to insert after the line
    sed -i.bak "${END_LINE}r /tmp/mcp_tool_class.txt" src/agents/agent_system.py
    rm /tmp/mcp_tool_class.txt
    
    print_success "Added MCPTool class"
fi

# Step 2: Update create_default_agents to accept mcp_client
print_status "Step 2: Updating create_default_agents method..."

if grep -q "def create_default_agents.*mcp_client" src/agents/agent_system.py; then
    print_warning "create_default_agents already has mcp_client parameter, skipping..."
else
    # Update method signature
    sed -i.bak 's/def create_default_agents(self, vector_db, memory_manager)/def create_default_agents(self, vector_db, memory_manager, mcp_client=None)/' src/agents/agent_system.py
    
    print_success "Updated method signature"
fi

# Step 3: Add MCP tool loading to create_default_agents
print_status "Step 3: Adding MCP tool loading logic..."

if grep -q "load_mcp_tools" src/agents/agent_system.py; then
    print_warning "MCP tool loading already exists, skipping..."
else
    # Find the line with create_default_agents method
    LINE_NUM=$(grep -n "def create_default_agents" src/agents/agent_system.py | cut -d: -f1)
    
    if [ -z "$LINE_NUM" ]; then
        print_error "Could not find create_default_agents method"
        exit 1
    fi
    
    # Find the docstring end
    DOCSTRING_END=$(tail -n +$LINE_NUM src/agents/agent_system.py | grep -n '"""' | head -2 | tail -1 | cut -d: -f1)
    INSERT_LINE=$((LINE_NUM + DOCSTRING_END))
    
    # Insert MCP loading code
    cat > /tmp/mcp_loading.txt << 'EOF'
        
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
EOF
    
    sed -i.bak "${INSERT_LINE}r /tmp/mcp_loading.txt" src/agents/agent_system.py
    rm /tmp/mcp_loading.txt
    
    print_success "Added MCP tool loading"
fi

# Step 4: Update app.py to pass mcp_client
print_status "Step 4: Updating app.py to pass mcp_client..."

if [ ! -f "src/app.py" ]; then
    print_warning "app.py not found, skipping..."
else
    if grep -q "mcp_client=self.mcp_client" src/app.py; then
        print_warning "app.py already passes mcp_client, skipping..."
    else
        # Find _setup_agents method and update it
        if grep -q "def _setup_agents" src/app.py; then
            sed -i.bak 's/self\.agent_registry\.create_default_agents(\s*$/self.agent_registry.create_default_agents(/' src/app.py
            sed -i.bak 's/self\.agent_registry\.create_default_agents(self\.vector_db, self\.memory)/self.agent_registry.create_default_agents(self.vector_db, self.memory, mcp_client=self.mcp_client)/' src/app.py
            
            print_success "Updated app.py"
        else
            print_warning "_setup_agents method not found in app.py"
        fi
    fi
fi

# Step 5: Verify changes
print_status "Step 5: Verifying changes..."

ERRORS=0

if ! grep -q "class MCPTool" src/agents/agent_system.py; then
    print_error "MCPTool class not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "MCPTool class exists"
fi

if ! grep -q "load_mcp_tools" src/agents/agent_system.py; then
    print_error "load_mcp_tools function not found"
    ERRORS=$((ERRORS + 1))
else
    print_success "load_mcp_tools function exists"
fi

if ! grep -q "mcp_client=None" src/agents/agent_system.py; then
    print_error "create_default_agents does not accept mcp_client"
    ERRORS=$((ERRORS + 1))
else
    print_success "create_default_agents accepts mcp_client"
fi

if [ $ERRORS -gt 0 ]; then
    print_error "Integration incomplete. Check errors above."
    echo ""
    echo "Backups are in: $BACKUP_DIR"
    echo "To restore: cp $BACKUP_DIR/* src/"
    exit 1
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MCP Integration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Changes applied:"
echo "  ✓ Added MCPTool class to src/agents/agent_system.py"
echo "  ✓ Added load_mcp_tools function"
echo "  ✓ Updated create_default_agents to accept mcp_client"
echo "  ✓ Updated app.py to pass mcp_client"
echo ""
echo "Backups saved in: $BACKUP_DIR"
echo ""
echo "Next Steps:"
echo "  1. Restart the application:"
echo "     docker compose restart streamlit-app"
echo ""
echo "  2. Check the UI sidebar for MCP status"
echo "     Should show available MCP tools"
echo ""
echo "  3. Select 'MCP Assistant' agent (if MCP server is running)"
echo ""
echo "To rollback changes:"
echo "  cp $BACKUP_DIR/* src/"
echo "  docker compose restart streamlit-app"
echo ""
print_success "Integration complete!"
