#!/usr/bin/env bash
#
# Klavis MCP Multi-Service Setup Script
# 
# This script sets up multiple Klavis MCP servers (Reddit, Gmail, Notion)
# Based on actual Klavis-AI/klavis repository
#
# Usage:
#   chmod +x scripts/setup_klavis_mcp.sh
#   ./scripts/setup_klavis_mcp.sh
#

set -e
set -u

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() { echo -e "${CYAN}========================================${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}========================================${NC}"; }
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

clear
print_header "Klavis MCP Multi-Service Setup (Option 1)"
echo ""
print_status "This script implements Klavis Option 1: Self-hosted infrastructure"
echo ""
print_status "Components:"
echo "  • Strata MCP Router (unified endpoint)"
echo "  • Reddit MCP Server"
echo "  • Gmail MCP Server (requires API key)"
echo "  • Notion MCP Server"
echo ""
print_warning "Based on: https://github.com/Klavis-AI/klavis"
echo ""

# Check Docker
print_status "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    echo "Start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi

print_success "Docker is available and running"

# Check for pipx (needed for Strata)
if ! command -v pipx &> /dev/null; then
    print_warning "pipx is not installed (needed for Strata MCP router)"
    print_status "Installing pipx..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y pipx || {
            print_error "Failed to install pipx via apt"
            print_status "Try manual install: python3 -m pip install --user pipx"
            exit 1
        }
        pipx ensurepath
    elif command -v brew &> /dev/null; then
        brew install pipx
        pipx ensurepath
    else
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
    fi
    print_success "pipx installed"
fi

echo ""

# Configuration
REDDIT_PORT="${REDDIT_PORT:-5000}"
GMAIL_PORT="${GMAIL_PORT:-5001}"
NOTION_PORT="${NOTION_PORT:-5002}"

REDDIT_IMAGE="ghcr.io/klavis-ai/reddit-mcp-server:latest"
GMAIL_IMAGE="ghcr.io/klavis-ai/gmail-mcp-server:latest"
NOTION_IMAGE="ghcr.io/klavis-ai/notion-mcp-server:latest"

# Ask which services to install
echo "Select services to install:"
echo ""
read -p "Install Reddit MCP? (Y/n): " -n 1 -r INSTALL_REDDIT
echo
INSTALL_REDDIT=${INSTALL_REDDIT:-Y}

read -p "Install Gmail MCP? (requires Klavis API key) (Y/n): " -n 1 -r INSTALL_GMAIL
echo
INSTALL_GMAIL=${INSTALL_GMAIL:-Y}

read -p "Install Notion MCP? (Y/n): " -n 1 -r INSTALL_NOTION
echo
INSTALL_NOTION=${INSTALL_NOTION:-Y}

# Get Klavis API key if needed
KLAVIS_API_KEY=""
if [[ $INSTALL_GMAIL =~ ^[Yy]$ ]]; then
    echo ""
    print_warning "Gmail MCP requires a Klavis API key"
    print_status "Get your API key from: https://klavis.ai/"
    echo ""
    read -p "Enter Klavis API key (or press Enter to skip Gmail): " KLAVIS_API_KEY
    
    if [ -z "$KLAVIS_API_KEY" ]; then
        print_warning "No API key provided. Skipping Gmail MCP."
        INSTALL_GMAIL="n"
    fi
fi

echo ""
print_header "Starting Installation"
echo ""

INSTALLED_SERVICES=()
FAILED_SERVICES=()

# Function to setup a service
setup_service() {
    local SERVICE_NAME=$1
    local CONTAINER_NAME=$2
    local IMAGE=$3
    local PORT=$4
    local REQUIRES_KEY=${5:-false}
    
    echo ""
    print_status "Setting up $SERVICE_NAME..."
    
    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "Container '$CONTAINER_NAME' already exists"
        read -p "Remove and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Removing existing container..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
        else
            print_status "Using existing container"
            if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                print_status "Starting existing container..."
                docker start "$CONTAINER_NAME" || {
                    print_error "Failed to start existing container"
                    FAILED_SERVICES+=("$SERVICE_NAME")
                    return 1
                }
            fi
            INSTALLED_SERVICES+=("$SERVICE_NAME|$CONTAINER_NAME|http://localhost:$PORT")
            return 0
        fi
    fi
    
    # Pull image
    print_status "Pulling Docker image: $IMAGE"
    if ! docker pull "$IMAGE" 2>&1 | grep -q "Status: Downloaded\|Status: Image is up to date"; then
        print_warning "Could not pull image. Attempting to run anyway..."
    fi
    
    # Run container
    print_status "Starting container..."
    if [ "$REQUIRES_KEY" = true ] && [ -n "$KLAVIS_API_KEY" ]; then
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$PORT:5000" \
            -e KLAVIS_API_KEY="$KLAVIS_API_KEY" \
            --restart unless-stopped \
            "$IMAGE" 2>&1
    else
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$PORT:5000" \
            --restart unless-stopped \
            "$IMAGE" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        print_success "$SERVICE_NAME started successfully"
        INSTALLED_SERVICES+=("$SERVICE_NAME|$CONTAINER_NAME|http://localhost:$PORT")
        
        # Wait a bit for container to start
        sleep 2
        
        # Check if container is still running
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            print_error "$SERVICE_NAME container stopped unexpectedly"
            print_status "Checking logs..."
            docker logs "$CONTAINER_NAME" 2>&1 | tail -10
            FAILED_SERVICES+=("$SERVICE_NAME")
            return 1
        fi
    else
        print_error "Failed to start $SERVICE_NAME"
        FAILED_SERVICES+=("$SERVICE_NAME")
        return 1
    fi
}

# Install selected services
if [[ $INSTALL_REDDIT =~ ^[Yy]$ ]]; then
    setup_service "Reddit MCP" "reddit-mcp" "$REDDIT_IMAGE" "$REDDIT_PORT"
fi

if [[ $INSTALL_GMAIL =~ ^[Yy]$ ]]; then
    setup_service "Gmail MCP" "gmail-mcp" "$GMAIL_IMAGE" "$GMAIL_PORT" true
fi

if [[ $INSTALL_NOTION =~ ^[Yy]$ ]]; then
    setup_service "Notion MCP" "notion-mcp" "$NOTION_IMAGE" "$NOTION_PORT"
fi

# Install Strata MCP Router
echo ""
print_header "Installing Strata MCP Router"
echo ""
print_status "Strata is Klavis's unified MCP router that provides:"
echo "  • Progressive tool discovery for AI agents"
echo "  • Scalable tool integration (beyond 40-50 tool limits)"
echo "  • Single endpoint for all MCP services"
echo ""

if command -v strata &> /dev/null; then
    print_success "Strata is already installed"
    strata --version || true
else
    print_status "Installing Strata via pipx..."
    pipx install strata-mcp || {
        print_error "Failed to install Strata"
        print_warning "You can still use individual MCP containers without Strata"
        print_status "To retry later: pipx install strata-mcp"
    }

    if command -v strata &> /dev/null; then
        print_success "Strata installed successfully"
        strata --version || true
    fi
fi

# Configure Strata with installed services
if command -v strata &> /dev/null && [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
    echo ""
    print_status "Configuring Strata with installed services..."

    # Create Strata config directory
    STRATA_CONFIG_DIR="$HOME/.config/strata"
    mkdir -p "$STRATA_CONFIG_DIR"

    # Create Strata configuration file
    cat > "$STRATA_CONFIG_DIR/config.json" << EOF
{
  "version": "1.0",
  "mcpServers": {
EOF

    # Add each installed service to Strata config
    first=true
    for service in "${INSTALLED_SERVICES[@]}"; do
        IFS='|' read -r name container url <<< "$service"
        service_key=$(echo "$name" | tr '[:upper:] ' '[:lower:]_' | sed 's/_mcp//')

        if [ "$first" = false ]; then
            echo "," >> "$STRATA_CONFIG_DIR/config.json"
        fi
        first=false

        cat >> "$STRATA_CONFIG_DIR/config.json" << SERVICEEOF
    "$service_key": {
      "url": "$url",
      "transport": "http"
    }
SERVICEEOF
    done

    cat >> "$STRATA_CONFIG_DIR/config.json" << EOF

  }
}
EOF

    print_success "Strata configuration created at: $STRATA_CONFIG_DIR/config.json"
fi

# Configure environment
echo ""
print_status "Configuring environment..."

ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    touch "$ENV_FILE"
    print_status "Created .env file"
fi

# Backup .env
cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Remove old MCP entries
sed -i.tmp '/# Klavis MCP/d' "$ENV_FILE"
sed -i.tmp '/MCP_.*_URL/d' "$ENV_FILE"
sed -i.tmp '/KLAVIS_API_KEY/d' "$ENV_FILE"
rm -f "${ENV_FILE}.tmp"

# Add new entries
echo "" >> "$ENV_FILE"
echo "# Klavis MCP Configuration (added by setup_klavis_mcp.sh)" >> "$ENV_FILE"
echo "# Option 1: Self-hosted infrastructure with Strata router" >> "$ENV_FILE"

# Add Strata endpoint if installed
if command -v strata &> /dev/null; then
    echo "STRATA_MCP_URL=http://localhost:8080" >> "$ENV_FILE"
    echo "USE_STRATA=true" >> "$ENV_FILE"
fi

# Add individual service URLs (for direct access or fallback)
for service in "${INSTALLED_SERVICES[@]}"; do
    IFS='|' read -r name container url <<< "$service"
    env_name=$(echo "$name" | tr '[:lower:] ' '[:upper:]_' | sed 's/_MCP//')
    echo "MCP_${env_name}_URL=$url" >> "$ENV_FILE"
done

if [ -n "$KLAVIS_API_KEY" ]; then
    echo "KLAVIS_API_KEY=$KLAVIS_API_KEY" >> "$ENV_FILE"
fi

print_success "Environment configured"

# Update docker-compose.yml to add network if needed
if [ -f "docker-compose.yml" ]; then
    echo ""
    print_status "Checking docker-compose.yml..."
    
    # Check if we need to add network config
    if ! grep -q "ai-network" docker-compose.yml; then
        print_warning "Consider adding MCP containers to docker-compose.yml"
        print_status "See KLAVIS_MCP_GUIDE.md for instructions"
    fi
fi

# Create/Update integration guide
cat > KLAVIS_MCP_GUIDE.md << 'GUIDE_EOF'
# Klavis MCP Integration Guide (Option 1)

This guide explains how to use Klavis Option 1: Self-hosted MCP infrastructure with Strata router.

## 🎯 What is Strata?

**Strata** is Klavis's Unified MCP Router that provides:
- **Progressive Tool Discovery**: Guides AI agents from intent → category → action → execution
- **Scalable Integration**: Handle 50+ tools without overwhelming your agent
- **Single Endpoint**: One URL for all MCP services (Reddit, Gmail, Notion, etc.)

## 🏗️ Architecture

### Without Strata (Direct Mode):
```
Your Agent → Reddit MCP (port 5000)
           → Gmail MCP (port 5001)
           → Notion MCP (port 5002)
```
**Problem**: Agent needs to know about all 3 services upfront

### With Strata (Option 1):
```
Your Agent → Strata Router (port 8080)
                   ↓
          [Progressive Discovery]
                   ↓
             Reddit MCP (port 5000)
             Gmail MCP (port 5001)
             Notion MCP (port 5002)
```
**Benefit**: Agent discovers tools progressively, reducing context overload

## Installed Services

Check `.env` file for configured services. Example:
```bash
# Strata Router (unified endpoint)
STRATA_MCP_URL=http://localhost:8080
USE_STRATA=true

# Individual Services (for direct access or fallback)
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
KLAVIS_API_KEY=your_key_here
```

## Quick Commands

### Check Running Services
```bash
docker ps | grep mcp
```

### View Logs
```bash
# Reddit
docker logs -f reddit-mcp

# Gmail
docker logs -f gmail-mcp

# Notion
docker logs -f notion-mcp
```

### Stop/Start Services
```bash
# Stop
docker stop reddit-mcp gmail-mcp notion-mcp

# Start
docker start reddit-mcp gmail-mcp notion-mcp

# Restart
docker restart reddit-mcp gmail-mcp notion-mcp
```

### Remove Services
```bash
# Stop and remove
docker rm -f reddit-mcp gmail-mcp notion-mcp

# Remove images (to save space)
docker rmi ghcr.io/klavis-ai/reddit-mcp-server
docker rmi ghcr.io/klavis-ai/gmail-mcp-server
docker rmi ghcr.io/klavis-ai/notion-mcp-server
```

## How to Add More Klavis MCP Services

Klavis provides 50+ MCP servers. Here's how to add more:

### Available Services

Check the full list at: https://github.com/Klavis-AI/klavis

Popular services:
- **GitHub**: `ghcr.io/klavis-ai/github-mcp-server`
- **Slack**: `ghcr.io/klavis-ai/slack-mcp-server`
- **YouTube**: `ghcr.io/klavis-ai/youtube-mcp-server`
- **Twitter**: `ghcr.io/klavis-ai/twitter-mcp-server`
- **Discord**: `ghcr.io/klavis-ai/discord-mcp-server`
- **Notion**: `ghcr.io/klavis-ai/notion-mcp-server`
- **Linear**: `ghcr.io/klavis-ai/linear-mcp-server`
- **Jira**: `ghcr.io/klavis-ai/jira-mcp-server`

### Manual Setup for New Service

Example: Adding GitHub MCP

```bash
# 1. Run the container
docker run -d \
  --name github-mcp \
  -p 5003:5000 \
  --restart unless-stopped \
  ghcr.io/klavis-ai/github-mcp-server:latest

# 2. Add to .env
echo "MCP_GITHUB_URL=http://localhost:5003" >> .env

# 3. Restart your app
docker compose restart streamlit-app
```

### Services Requiring API Keys

Some services need the Klavis API key:

```bash
# Example: Gmail (already setup)
docker run -d \
  --name gmail-mcp \
  -p 5001:5000 \
  -e KLAVIS_API_KEY=your_key_here \
  --restart unless-stopped \
  ghcr.io/klavis-ai/gmail-mcp-server:latest
```

Get API key from: https://klavis.ai/

### Add to docker-compose.yml (Optional)

For permanent setup, add to `docker-compose.yml`:

```yaml
services:
  # ... existing services ...
  
  reddit-mcp:
    image: ghcr.io/klavis-ai/reddit-mcp-server:latest
    container_name: reddit-mcp
    ports:
      - "5000:5000"
    restart: unless-stopped
    networks:
      - ai-network
  
  gmail-mcp:
    image: ghcr.io/klavis-ai/gmail-mcp-server:latest
    container_name: gmail-mcp
    ports:
      - "5001:5000"
    environment:
      - KLAVIS_API_KEY=${KLAVIS_API_KEY}
    restart: unless-stopped
    networks:
      - ai-network
  
  notion-mcp:
    image: ghcr.io/klavis-ai/notion-mcp-server:latest
    container_name: notion-mcp
    ports:
      - "5002:5000"
    restart: unless-stopped
    networks:
      - ai-network
```

Then run:
```bash
docker compose up -d
```

## Using Strata Client in Python

### Option A: Use Strata Router (Recommended)

```python
from src.klavis_strata_client import StrataClient

# Create client (reads from .env automatically)
client = StrataClient()

# Progressive discovery - Step 1: Discover categories
categories = client.discover_categories()
# Returns: ["reddit", "gmail", "notion"]

# Progressive discovery - Step 2: Discover actions in a category
reddit_actions = client.discover_actions("reddit")
# Returns: List of available Reddit tools

# List all available tools
tools = client.list_tools()

# Call a tool
result = client.call_tool(
    "reddit_get_hot_posts",
    {"subreddit": "python", "limit": 5}
)

# Health check
health = client.health_check()
print(health)
```

### Option B: Use Direct Service URLs (Fallback)

```python
from klavis import KlavisClient
import os

# Read from environment
reddit_url = os.getenv('MCP_REDDIT_URL', 'http://localhost:5000')
gmail_url = os.getenv('MCP_GMAIL_URL', 'http://localhost:5001')
notion_url = os.getenv('MCP_NOTION_URL', 'http://localhost:5002')
api_key = os.getenv('KLAVIS_API_KEY')

# Create clients for each service
reddit = KlavisClient(base_url=reddit_url)
gmail = KlavisClient(api_key=api_key, base_url=gmail_url)
notion = KlavisClient(base_url=notion_url)
```

### Automatic Fallback

The `StrataClient` automatically falls back to direct URLs if Strata is unavailable:

```python
client = StrataClient()

# If Strata is down, client automatically uses direct service URLs
# No code changes needed!
result = client.call_tool("reddit_get_hot_posts", {...})
```

## Integrating with AI Agents

### Using Strata Client (Recommended)

The Strata client provides progressive discovery and automatic fallback.

### 1. Create Strata Tool Wrapper

Edit `src/agents/agent_system.py` and add:

```python
from src.klavis_strata_client import StrataClient
from typing import Any, Dict

class StrataMCPTool(Tool):
    """Tool for Klavis Strata MCP router"""

    def __init__(self):
        self.client = StrataClient()
        self._categories = None

    def name(self) -> str:
        return "strata_mcp"

    def description(self) -> str:
        return "Access Reddit, Gmail, Notion, and other services via Klavis Strata MCP router. Supports progressive tool discovery."

    def get_categories(self) -> list:
        """Discover available service categories"""
        if self._categories is None:
            self._categories = self.client.discover_categories()
        return self._categories

    def discover_actions(self, category: str) -> list:
        """Discover available actions in a category"""
        return self.client.discover_actions(category)

    def execute(self, tool_name: str, parameters: Dict[str, Any]) -> Any:
        """Execute a tool via Strata"""
        try:
            result = self.client.call_tool(tool_name, parameters)
            return result
        except Exception as e:
            return {"error": str(e), "tool": tool_name}
```

### 2. Add Strata Tool to Agents

```python
# In create_default_agents() method
import os

# Check if Strata is enabled
if os.getenv('USE_STRATA', 'false').lower() == 'true':
    strata_tool = StrataMCPTool()

    # Create agent with Strata tool
    strata_agent = Agent(
        AgentConfig(
            name="Strata Assistant",
            system_prompt="""You have access to multiple services via Strata MCP router.

Available categories: {categories}

Use progressive discovery:
1. Call get_categories() to see what's available
2. Call discover_actions(category) to see actions in a category
3. Call execute(tool_name, parameters) to run the action

Examples:
- Reddit: execute("reddit_get_hot_posts", {{"subreddit": "python", "limit": 5}})
- Gmail: execute("gmail_list_messages", {{"max_results": 10}})
- Notion: execute("notion_query_database", {{"database_id": "..."}})
""".format(categories=", ".join(strata_tool.get_categories())),
            temperature=0.6
        ),
        tools=[strata_tool]
    )
    self.register(strata_agent)
else:
    # Fallback to direct MCP clients (see Option B above)
    pass
```

### 3. Test Integration

```python
# Test script: test_strata.py
from src.klavis_strata_client import StrataClient

client = StrataClient()

# Test health
print("Health:", client.health_check())

# Test discovery
print("\nCategories:", client.discover_categories())

# Test Reddit
result = client.call_tool(
    "reddit_get_hot_posts",
    {"subreddit": "python", "limit": 3}
)
print("\nReddit result:", result)
```

### 4. Restart Application
```bash
# If using systemd
systemctl --user restart agentic-ai

# If using manual mode
./run_local.sh
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs <container-name>

# Check if port is already in use
sudo lsof -i :<port>

# Try different port
docker run -d --name reddit-mcp -p 5010:5000 ghcr.io/klavis-ai/reddit-mcp-server:latest
```

### Image Not Found
```bash
# Check available images
docker search klavis

# Try pulling manually
docker pull ghcr.io/klavis-ai/reddit-mcp-server:latest

# Check GitHub Container Registry
# https://github.com/orgs/Klavis-AI/packages
```

### Service Not Responding
```bash
# Check if container is running
docker ps | grep mcp

# Check container health
docker inspect <container-name>

# Restart service
docker restart <container-name>
```

### API Key Issues
```bash
# Verify API key is set
echo $KLAVIS_API_KEY

# Check if container has the key
docker exec <container-name> env | grep KLAVIS

# Re-create with key
docker rm -f <container-name>
docker run -d ... -e KLAVIS_API_KEY=your_key ...
```

## Resources

- **Klavis GitHub**: https://github.com/Klavis-AI/klavis
- **Klavis Docs**: https://docs.klavis.ai/
- **Get API Key**: https://klavis.ai/
- **Container Registry**: https://github.com/orgs/Klavis-AI/packages

## Re-running the Setup Script

To add more services or reconfigure:

```bash
# Run the setup script again
./scripts/setup_klavis_mcp.sh

# It will detect existing containers and ask if you want to keep or replace them
```

## Managed Service Alternative

If self-hosting is too complex, Klavis offers a managed service:
- **URL**: https://klavis.ai/
- **Features**: 99.9% uptime, enterprise OAuth, 50+ integrations
- **Benefit**: No Docker setup needed

---

**Need help?** Check the official Klavis documentation or open an issue on their GitHub.
GUIDE_EOF

print_success "Created KLAVIS_MCP_GUIDE.md"

# Final summary
echo ""
print_header "Setup Complete!"
echo ""

if [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
    print_success "Successfully installed ${#INSTALLED_SERVICES[@]} service(s):"
    echo ""
    for service in "${INSTALLED_SERVICES[@]}"; do
        IFS='|' read -r name container url <<< "$service"
        echo "  ✓ $name"
        echo "    Container: $container"
        echo "    URL: $url"
        echo "    Logs: docker logs -f $container"
        echo ""
    done
fi

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    print_warning "Failed to install ${#FAILED_SERVICES[@]} service(s):"
    for service in "${FAILED_SERVICES[@]}"; do
        echo "  ✗ $service"
    done
    echo ""
fi

echo "Configuration:"
echo "  ✓ Environment variables added to .env"
echo "  ✓ Backup created: .env.backup.*"
echo "  ✓ Guide created: KLAVIS_MCP_GUIDE.md"
echo ""

echo "Quick Commands:"
echo "  View services:  docker ps | grep mcp"
echo "  View logs:      docker logs -f <container-name>"
echo "  Stop all:       docker stop reddit-mcp gmail-mcp notion-mcp"
echo "  Start all:      docker start reddit-mcp gmail-mcp notion-mcp"
echo ""

echo "Next Steps:"
echo "  1. Read the integration guide:"
echo "     cat KLAVIS_MCP_GUIDE.md"
echo ""
echo "  2. Install Klavis client:"
echo "     pip install klavis"
echo ""
echo "  3. Integrate with your agents (see guide)"
echo ""
echo "  4. To add more services:"
echo "     - See 'How to Add More' in KLAVIS_MCP_GUIDE.md"
echo "     - Or re-run: ./scripts/setup_klavis_mcp.sh"
echo ""

echo "Documentation:"
echo "  • Integration guide: KLAVIS_MCP_GUIDE.md"
echo "  • Klavis GitHub: https://github.com/Klavis-AI/klavis"
echo "  • Get API key: https://klavis.ai/"
echo ""

print_success "Klavis MCP services are ready!"
