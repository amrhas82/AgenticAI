#!/usr/bin/env bash
#
# Klavis MCP Real Setup Script
# Based on actual Klavis-AI/klavis GitHub repository
#
# This script sets up Klavis MCP servers for your AI agent.
# You can choose which services to integrate.
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
echo -e "${BLUE}  Klavis MCP Real Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

print_warning "IMPORTANT: Klavis MCP uses separate servers for each service"
print_status "Available services: GitHub, Gmail, Slack, YouTube, and 50+ more"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
fi

print_success "Docker is available"

# Show available services
echo ""
echo "Available Klavis MCP Servers:"
echo "  1) GitHub    - ghcr.io/klavis-ai/github-mcp-server"
echo "  2) Gmail     - ghcr.io/klavis-ai/gmail-mcp-server (requires API key)"
echo "  3) Slack     - ghcr.io/klavis-ai/slack-mcp-server"
echo "  4) YouTube   - ghcr.io/klavis-ai/youtube-mcp-server"
echo "  5) Custom    - Specify your own"
echo "  6) Build from source"
echo ""

read -p "Select service to install (1-6): " choice

case $choice in
    1)
        SERVICE_NAME="github"
        IMAGE="ghcr.io/klavis-ai/github-mcp-server:latest"
        PORT="5000"
        REQUIRES_KEY=false
        ;;
    2)
        SERVICE_NAME="gmail"
        IMAGE="ghcr.io/klavis-ai/gmail-mcp-server:latest"
        PORT="5001"
        REQUIRES_KEY=true
        ;;
    3)
        SERVICE_NAME="slack"
        IMAGE="ghcr.io/klavis-ai/slack-mcp-server:latest"
        PORT="5002"
        REQUIRES_KEY=false
        ;;
    4)
        SERVICE_NAME="youtube"
        IMAGE="ghcr.io/klavis-ai/youtube-mcp-server:latest"
        PORT="5003"
        REQUIRES_KEY=false
        ;;
    5)
        read -p "Enter service name: " SERVICE_NAME
        read -p "Enter Docker image: " IMAGE
        read -p "Enter port: " PORT
        read -p "Requires Klavis API key? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            REQUIRES_KEY=true
        else
            REQUIRES_KEY=false
        fi
        ;;
    6)
        echo ""
        print_status "To build from source:"
        echo ""
        echo "  git clone https://github.com/Klavis-AI/klavis.git"
        echo "  cd klavis/mcp_servers/<service>"
        echo "  # Follow README.md in that directory"
        echo ""
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
print_status "Setting up: $SERVICE_NAME"
print_status "Image: $IMAGE"
print_status "Port: $PORT"

# Get API key if required
if [ "$REQUIRES_KEY" = true ]; then
    echo ""
    print_warning "This service requires a Klavis API key"
    echo "Get your key from: https://klavis.ai/"
    read -p "Enter Klavis API key: " KLAVIS_API_KEY
    
    if [ -z "$KLAVIS_API_KEY" ]; then
        print_error "API key is required for this service"
        exit 1
    fi
fi

# Pull image
print_status "Pulling Docker image..."
if ! docker pull "$IMAGE"; then
    print_error "Failed to pull image. It may not exist or you may need authentication."
    echo ""
    echo "Available images at: https://github.com/orgs/Klavis-AI/packages"
    exit 1
fi

print_success "Image pulled"

# Stop existing container
CONTAINER_NAME="${SERVICE_NAME}-mcp-server"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_status "Removing existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Run container
print_status "Starting MCP server..."

if [ "$REQUIRES_KEY" = true ]; then
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:5000" \
        -e KLAVIS_API_KEY="$KLAVIS_API_KEY" \
        --restart unless-stopped \
        "$IMAGE"
else
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:5000" \
        --restart unless-stopped \
        "$IMAGE"
fi

print_success "MCP server started"

# Wait for server
print_status "Waiting for server to be ready..."
sleep 3

# Configure .env
ENV_FILE=".env"
MCP_URL="http://localhost:$PORT"

if [ ! -f "$ENV_FILE" ]; then
    touch "$ENV_FILE"
fi

# Update or add MCP_URL
if grep -q "^MCP_URL=" "$ENV_FILE"; then
    sed -i.bak "s|^MCP_URL=.*|MCP_URL=${MCP_URL}|" "$ENV_FILE"
else
    echo "" >> "$ENV_FILE"
    echo "# Klavis MCP Configuration" >> "$ENV_FILE"
    echo "MCP_URL=${MCP_URL}" >> "$ENV_FILE"
fi

if [ "$REQUIRES_KEY" = true ] && ! grep -q "^KLAVIS_API_KEY=" "$ENV_FILE"; then
    echo "KLAVIS_API_KEY=${KLAVIS_API_KEY}" >> "$ENV_FILE"
fi

print_success "Environment configured"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Service: $SERVICE_NAME"
echo "Container: $CONTAINER_NAME"
echo "URL: $MCP_URL"
echo ""
echo "Quick Commands:"
echo "  Status:  docker ps | grep $CONTAINER_NAME"
echo "  Logs:    docker logs -f $CONTAINER_NAME"
echo "  Stop:    docker stop $CONTAINER_NAME"
echo "  Start:   docker start $CONTAINER_NAME"
echo ""
echo "Next Steps:"
echo "  1. Install Klavis client:"
echo "     pip install klavis"
echo ""
echo "  2. Test the server (check docs for actual endpoints)"
echo ""
echo "  3. Integrate with your agent (see Klavis docs)"
echo ""
echo "Documentation:"
echo "  GitHub: https://github.com/Klavis-AI/klavis"
echo "  Docs:   https://docs.klavis.ai/"
echo ""
print_success "Klavis MCP server is running!"
