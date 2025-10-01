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
print_header "Klavis MCP Multi-Service Setup"
echo ""
print_status "This script will setup multiple Klavis MCP servers:"
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
# Klavis MCP Integration Guide

This guide explains how to use the installed Klavis MCP servers and add more services.

## Installed Services

Check `.env` file for configured services. Example:
```bash
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

## Using Klavis Client in Python

### Install Client
```bash
pip install klavis
```

### Basic Usage
```python
from klavis import KlavisClient

# Connect to a service
reddit_client = KlavisClient(
    api_key='your_api_key',  # If required
    base_url='http://localhost:5000'  # Reddit MCP
)

# Use the client (check Klavis docs for specific methods)
# Example usage will depend on the service
```

### Multiple Services
```python
from klavis import KlavisClient
import os

# Read from environment
reddit_url = os.getenv('MCP_REDDIT_URL', 'http://localhost:5000')
gmail_url = os.getenv('MCP_GMAIL_URL', 'http://localhost:5001')
notion_url = os.getenv('MCP_NOTION_URL', 'http://localhost:5002')
api_key = os.getenv('KLAVIS_API_KEY')

# Create clients
reddit = KlavisClient(base_url=reddit_url)
gmail = KlavisClient(api_key=api_key, base_url=gmail_url)
notion = KlavisClient(base_url=notion_url)
```

## Integrating with AI Agents

To integrate Klavis MCP with your AI agents, you'll need to:

### 1. Install Klavis Client
```bash
pip install klavis
```

### 2. Create Klavis Tool Wrapper

Edit `src/agents/agent_system.py` and add:

```python
from klavis import KlavisClient

class KlavisMCPTool(Tool):
    """Tool for Klavis MCP services"""
    
    def __init__(self, service_name: str, base_url: str, api_key: str = None):
        self.service_name = service_name
        self.client = KlavisClient(base_url=base_url, api_key=api_key)
    
    def name(self) -> str:
        return f"klavis_{self.service_name}"
    
    def description(self) -> str:
        return f"Access {self.service_name} via Klavis MCP"
    
    def execute(self, method: str, **kwargs) -> Any:
        """Execute a method on the Klavis client"""
        try:
            # This will depend on the specific service's API
            # Check Klavis docs for each service
            result = getattr(self.client, method)(**kwargs)
            return result
        except Exception as e:
            return {"error": str(e)}
```

### 3. Add Tools to Agents

```python
# In create_default_agents() method
import os

# Load MCP URLs from environment
reddit_url = os.getenv('MCP_REDDIT_URL')
gmail_url = os.getenv('MCP_GMAIL_URL')
notion_url = os.getenv('MCP_NOTION_URL')
api_key = os.getenv('KLAVIS_API_KEY')

klavis_tools = []

if reddit_url:
    klavis_tools.append(KlavisMCPTool('reddit', reddit_url))

if gmail_url and api_key:
    klavis_tools.append(KlavisMCPTool('gmail', gmail_url, api_key))

if notion_url:
    klavis_tools.append(KlavisMCPTool('notion', notion_url))

# Add to agent
if klavis_tools:
    klavis_agent = Agent(
        AgentConfig(
            name="Klavis Assistant",
            system_prompt="You have access to Reddit, Gmail, and Notion via Klavis MCP.",
            temperature=0.6
        ),
        tools=klavis_tools
    )
    self.register(klavis_agent)
```

### 4. Restart Application
```bash
docker compose restart streamlit-app
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
