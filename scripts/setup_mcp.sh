#!/usr/bin/env bash
#
# MCP (Model Context Protocol) Klavis Setup Script
# 
# This script automates the setup of MCP Klavis integration for the AI Agent system.
# It will:
#   1. Check for Docker availability
#   2. Pull/run the MCP server container
#   3. Configure environment variables
#   4. Apply code changes to integrate MCP with agents
#   5. Verify the setup
#
# Usage:
#   chmod +x scripts/setup_mcp.sh
#   ./scripts/setup_mcp.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MCP_PORT="${MCP_PORT:-8080}"
MCP_IMAGE="${MCP_IMAGE:-klavis/mcp-server:latest}"
MCP_CONTAINER_NAME="${MCP_CONTAINER_NAME:-mcp-server}"
MCP_URL="http://localhost:${MCP_PORT}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MCP Klavis Setup for AI Agents${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Step 1: Check Docker
print_status "Step 1: Checking Docker availability..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH."
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running."
    echo "Please start Docker Desktop or run: sudo systemctl start docker"
    exit 1
fi

print_success "Docker is available and running"

# Step 2: Check if MCP container already exists
print_status "Step 2: Checking for existing MCP server..."

if docker ps -a --format '{{.Names}}' | grep -q "^${MCP_CONTAINER_NAME}$"; then
    print_warning "MCP container '${MCP_CONTAINER_NAME}' already exists."
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Stopping and removing existing container..."
        docker stop "${MCP_CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${MCP_CONTAINER_NAME}" 2>/dev/null || true
        print_success "Removed existing container"
    else
        print_status "Keeping existing container. Checking if it's running..."
        if ! docker ps --format '{{.Names}}' | grep -q "^${MCP_CONTAINER_NAME}$"; then
            print_status "Starting existing container..."
            docker start "${MCP_CONTAINER_NAME}"
        fi
    fi
fi

# Step 3: Pull/Run MCP Server
if ! docker ps --format '{{.Names}}' | grep -q "^${MCP_CONTAINER_NAME}$"; then
    print_status "Step 3: Setting up MCP server container..."
    
    # Check if we need to pull the image
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${MCP_IMAGE}$"; then
        print_status "Pulling MCP server image: ${MCP_IMAGE}"
        docker pull "${MCP_IMAGE}" || {
            print_warning "Failed to pull official image. Trying alternative setup..."
            print_status "You may need to build MCP from source. See: https://github.com/Klavis-AI/klavis"
            exit 1
        }
    fi
    
    print_status "Starting MCP server container..."
    docker run -d \
        --name "${MCP_CONTAINER_NAME}" \
        -p "${MCP_PORT}:8080" \
        --restart unless-stopped \
        "${MCP_IMAGE}" || {
        print_error "Failed to start MCP container"
        exit 1
    }
    
    print_success "MCP server container started"
else
    print_success "MCP server container is already running"
fi

# Step 4: Wait for MCP to be ready
print_status "Step 4: Waiting for MCP server to be ready..."

MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -sf "${MCP_URL}/health" > /dev/null 2>&1; then
        print_success "MCP server is ready!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        print_error "MCP server did not become ready in time"
        echo "Check logs with: docker logs ${MCP_CONTAINER_NAME}"
        exit 1
    fi
    echo -n "."
    sleep 1
done
echo ""

# Step 5: Configure environment variables
print_status "Step 5: Configuring environment variables..."

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    print_status "Creating .env file..."
    touch "$ENV_FILE"
fi

# Check if MCP_URL already exists
if grep -q "^MCP_URL=" "$ENV_FILE"; then
    print_status "Updating existing MCP_URL in .env"
    sed -i.bak "s|^MCP_URL=.*|MCP_URL=${MCP_URL}|" "$ENV_FILE"
else
    print_status "Adding MCP_URL to .env"
    echo "" >> "$ENV_FILE"
    echo "# MCP Configuration (added by setup_mcp.sh)" >> "$ENV_FILE"
    echo "MCP_URL=${MCP_URL}" >> "$ENV_FILE"
fi

# Add ENABLE_MCP flag
if ! grep -q "^ENABLE_MCP=" "$ENV_FILE"; then
    echo "ENABLE_MCP=true" >> "$ENV_FILE"
fi

print_success "Environment variables configured"

# Step 6: Test MCP connection
print_status "Step 6: Testing MCP connection..."

MCP_STATUS=$(curl -s "${MCP_URL}/api/info" 2>/dev/null || echo "error")

if [[ "$MCP_STATUS" != "error" ]]; then
    print_success "MCP server is responding"
    echo "Server info: $MCP_STATUS" | head -c 100
    echo "..."
else
    print_warning "MCP server might not be fully ready yet"
fi

# Step 7: Check for available MCP tools
print_status "Step 7: Checking available MCP tools..."

MCP_TOOLS=$(curl -s "${MCP_URL}/api/tools" 2>/dev/null || echo '{"tools":[]}')
TOOL_COUNT=$(echo "$MCP_TOOLS" | grep -o '"name"' | wc -l)

if [ "$TOOL_COUNT" -gt 0 ]; then
    print_success "Found $TOOL_COUNT MCP tools available"
else
    print_warning "No MCP tools found (this might be normal for a fresh server)"
fi

# Step 8: Apply code integration (optional)
echo ""
print_status "Step 8: Code integration..."
echo ""
print_warning "To integrate MCP tools with your AI agents, you need to apply code changes."
echo ""
echo "Option 1: Automatic integration (recommended)"
echo "  Run: ./scripts/integrate_mcp_code.sh"
echo ""
echo "Option 2: Manual integration"
echo "  Follow the guide in: AGENT_IMPROVEMENTS.md - Section 2"
echo ""
read -p "Run automatic integration now? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "scripts/integrate_mcp_code.sh" ]; then
        print_status "Running automatic integration..."
        bash scripts/integrate_mcp_code.sh
    else
        print_error "Integration script not found. Please run manual integration."
        echo "See: AGENT_IMPROVEMENTS.md - Section 2"
    fi
else
    print_status "Skipping automatic integration. You can run it later."
fi

# Step 9: Add to docker-compose (optional)
echo ""
print_status "Step 9: Docker Compose integration..."
echo ""

if [ -f "docker-compose.yml" ]; then
    if grep -q "mcp-server:" docker-compose.yml; then
        print_success "MCP server already in docker-compose.yml"
    else
        print_warning "MCP server is running standalone (not in docker-compose.yml)"
        echo ""
        echo "To add MCP to docker-compose.yml, add this service:"
        echo ""
        cat << 'EOF'
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
EOF
        echo ""
    fi
fi

# Step 10: Verify setup
echo ""
print_status "Step 10: Verifying setup..."
echo ""

# Check container status
if docker ps --format '{{.Names}}\t{{.Status}}' | grep "^${MCP_CONTAINER_NAME}"; then
    print_success "Container is running"
else
    print_error "Container is not running"
fi

# Check port
if netstat -tln 2>/dev/null | grep -q ":${MCP_PORT}" || ss -tln 2>/dev/null | grep -q ":${MCP_PORT}"; then
    print_success "Port ${MCP_PORT} is listening"
else
    print_warning "Port ${MCP_PORT} might not be accessible"
fi

# Check health endpoint
if curl -sf "${MCP_URL}/health" > /dev/null 2>&1; then
    print_success "Health endpoint is responding"
else
    print_error "Health endpoint is not responding"
fi

# Final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MCP Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "MCP Server Details:"
echo "  Container: ${MCP_CONTAINER_NAME}"
echo "  URL: ${MCP_URL}"
echo "  Health: ${MCP_URL}/health"
echo "  Tools: ${MCP_URL}/api/tools"
echo ""
echo "Quick Commands:"
echo "  Status:  docker ps | grep ${MCP_CONTAINER_NAME}"
echo "  Logs:    docker logs -f ${MCP_CONTAINER_NAME}"
echo "  Stop:    docker stop ${MCP_CONTAINER_NAME}"
echo "  Start:   docker start ${MCP_CONTAINER_NAME}"
echo "  Remove:  docker rm -f ${MCP_CONTAINER_NAME}"
echo ""
echo "Test MCP Connection:"
echo "  curl ${MCP_URL}/health"
echo "  curl ${MCP_URL}/api/tools"
echo ""
echo "Next Steps:"
echo "  1. Restart your AI Agent app to load MCP configuration"
echo "     docker compose restart streamlit-app"
echo ""
echo "  2. Check MCP status in the app sidebar"
echo "     Open: http://localhost:8501"
echo "     Look for: 'MCP Integration' section"
echo ""
echo "  3. If not integrated yet, run code integration:"
echo "     ./scripts/integrate_mcp_code.sh"
echo "     OR follow: AGENT_IMPROVEMENTS.md - Section 2"
echo ""
echo "Documentation:"
echo "  - Complete guide: docs/AI_AGENT_GUIDE.md - Section 2"
echo "  - Quick reference: QUICK_REFERENCE.md"
echo "  - Implementation: AGENT_IMPROVEMENTS.md - Section 2"
echo ""
print_success "Setup complete! MCP Klavis is ready to use."
