#!/bin/bash
# Self-Hosted MCP Setup Script
# Sets up Reddit, Gmail, and Notion MCP servers using open source implementations

set -euo pipefail

echo "🏠 Self-Hosted MCP Setup"
echo "========================"
echo ""

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_DIR="$PROJECT_DIR/mcp-servers"

mkdir -p "$MCP_DIR"
cd "$MCP_DIR"

# 1. Reddit MCP (no auth needed)
echo "📱 Setting up Reddit MCP..."
cat > Dockerfile.reddit << 'EOF'
FROM python:3.11-slim

RUN pip install mcp-server-reddit

EXPOSE 5000

CMD ["python", "-m", "mcp_server_reddit", "--port", "5000"]
EOF

docker build -t reddit-mcp -f Dockerfile.reddit . || {
    echo "⚠️  Docker build failed. Is Docker installed and running?"
    echo "   Install: sudo apt install docker.io"
    echo "   Start: sudo systemctl start docker"
    exit 1
}

echo "✅ Reddit MCP ready"
echo ""

# 2. Gmail MCP (requires credentials)
echo "📧 Setting up Gmail MCP..."
echo ""
echo "Gmail requires OAuth2 credentials from Google Cloud Console."
echo "Steps to get credentials:"
echo "  1. Go to https://console.cloud.google.com"
echo "  2. Create a new project (or select existing)"
echo "  3. Enable Gmail API"
echo "  4. Create OAuth2 credentials (Desktop app)"
echo "  5. Download credentials.json"
echo ""

if [ ! -f "$MCP_DIR/gmail-credentials.json" ]; then
    echo "⚠️  Gmail credentials not found at: $MCP_DIR/gmail-credentials.json"
    echo ""
    read -p "Do you have gmail-credentials.json ready? [y/N]: " has_creds

    if [[ "$has_creds" =~ ^[Yy]$ ]]; then
        read -p "Enter path to your credentials.json: " creds_path
        if [ -f "$creds_path" ]; then
            cp "$creds_path" "$MCP_DIR/gmail-credentials.json"
            echo "✅ Credentials copied"
        else
            echo "❌ File not found: $creds_path"
            has_creds="n"
        fi
    fi
else
    echo "✅ Gmail credentials found"
    has_creds="y"
fi

if [[ "$has_creds" =~ ^[Yy]$ ]]; then
    if [ ! -d "$MCP_DIR/gmail-mcp" ]; then
        echo "Cloning Gmail MCP repository..."
        git clone https://github.com/GongRzhe/Gmail-MCP-Server.git gmail-mcp
    fi

    cd gmail-mcp

    # Check if npm is installed
    if command -v npm &> /dev/null; then
        npm install || echo "⚠️  npm install failed"
        echo "✅ Gmail MCP ready"
    else
        echo "⚠️  npm not found. Install Node.js:"
        echo "   sudo apt install nodejs npm"
    fi

    cd ..
else
    echo "⏭️  Skipping Gmail setup"
    echo "   You can add credentials later and re-run this script"
fi
echo ""

# 3. Notion MCP (requires token)
echo "📝 Setting up Notion MCP..."
echo ""
echo "Notion requires an integration token from your workspace."
echo "Steps to get token:"
echo "  1. Go to https://www.notion.so/my-integrations"
echo "  2. Create new internal integration"
echo "  3. Copy the token (starts with 'ntn_')"
echo "  4. Share specific Notion pages with the integration"
echo ""

read -p "Enter Notion Integration Token (or press Enter to skip): " notion_token

if [ -n "$notion_token" ]; then
    echo "NOTION_TOKEN=$notion_token" > .env.notion

    # Pull official Notion MCP image
    docker pull mcp/notion || {
        echo "⚠️  Failed to pull Notion MCP image"
        echo "   Check Docker Hub access"
    }

    echo "✅ Notion MCP ready"
else
    echo "⏭️  Skipping Notion setup"
    echo "   Get token at: https://www.notion.so/my-integrations"
    echo "   Then create $MCP_DIR/.env.notion with:"
    echo "   NOTION_TOKEN=your_token_here"
fi
echo ""

# 4. Create docker-compose for all services
echo "🐳 Creating docker-compose configuration..."

# Determine which services to include
COMPOSE_PROFILES=""
if [[ "$has_creds" =~ ^[Yy]$ ]] && [ -f "$MCP_DIR/gmail-mcp/package.json" ]; then
    COMPOSE_PROFILES="gmail"
fi

if [ -f "$MCP_DIR/.env.notion" ]; then
    COMPOSE_PROFILES="${COMPOSE_PROFILES:+$COMPOSE_PROFILES,}notion"
fi

cat > docker-compose.yml << EOF
version: '3.8'

services:
  reddit-mcp:
    build:
      context: .
      dockerfile: Dockerfile.reddit
    container_name: reddit-mcp
    ports:
      - "5000:5000"
    restart: unless-stopped
    networks:
      - mcp-network

  gmail-mcp:
    build:
      context: ./gmail-mcp
    container_name: gmail-mcp
    ports:
      - "5001:5001"
    volumes:
      - ./gmail-credentials.json:/app/credentials.json:ro
      - ./gmail-tokens:/app/tokens
    environment:
      - GMAIL_CREDENTIALS=/app/credentials.json
    restart: unless-stopped
    networks:
      - mcp-network
    profiles:
      - gmail

  notion-mcp:
    image: mcp/notion
    container_name: notion-mcp
    ports:
      - "5002:5002"
    env_file:
      - .env.notion
    restart: unless-stopped
    networks:
      - mcp-network
    profiles:
      - notion

networks:
  mcp-network:
    driver: bridge
EOF

echo "✅ Docker compose configuration created"
echo ""

# 5. Update project .env
echo "📄 Updating project configuration..."
cd "$PROJECT_DIR"

# Backup existing .env
if [ -f .env ]; then
    cp .env .env.backup.$(date +%s)
fi

# Add MCP configuration if not present
if ! grep -q "MCP_SELF_HOSTED" .env 2>/dev/null; then
    cat >> .env << 'EOF'

# Self-Hosted MCP Servers
MCP_SELF_HOSTED=true
MCP_REDDIT_URL=http://localhost:5000
MCP_GMAIL_URL=http://localhost:5001
MCP_NOTION_URL=http://localhost:5002
EOF
    echo "✅ Configuration added to .env"
else
    echo "✅ Configuration already exists in .env"
fi

echo ""

# 6. Create management scripts
echo "🛠️  Creating management scripts..."

cat > "$MCP_DIR/start.sh" << 'EOF'
#!/bin/bash
# Start MCP services

set -e

echo "Starting MCP services..."

# Start Reddit (always available)
docker-compose up -d reddit-mcp

# Start Gmail if configured
if [ -f gmail-credentials.json ]; then
    docker-compose --profile gmail up -d
fi

# Start Notion if configured
if [ -f .env.notion ]; then
    docker-compose --profile notion up -d
fi

echo ""
echo "✅ Services started"
echo ""
echo "Check status: docker-compose ps"
echo "View logs: docker-compose logs -f"
EOF

cat > "$MCP_DIR/stop.sh" << 'EOF'
#!/bin/bash
# Stop MCP services

docker-compose down

echo "✅ All MCP services stopped"
EOF

cat > "$MCP_DIR/test.sh" << 'EOF'
#!/bin/bash
# Test MCP services

echo "Testing MCP services..."
echo ""

# Test Reddit
echo "📱 Reddit MCP (localhost:5000):"
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "   ✅ Running"
else
    echo "   ❌ Not responding"
fi

# Test Gmail
echo "📧 Gmail MCP (localhost:5001):"
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo "   ✅ Running"
else
    echo "   ⏸️  Not running (may not be configured)"
fi

# Test Notion
echo "📝 Notion MCP (localhost:5002):"
if curl -s http://localhost:5002/health > /dev/null 2>&1; then
    echo "   ✅ Running"
else
    echo "   ⏸️  Not running (may not be configured)"
fi

echo ""
EOF

chmod +x "$MCP_DIR/start.sh"
chmod +x "$MCP_DIR/stop.sh"
chmod +x "$MCP_DIR/test.sh"

echo "✅ Management scripts created"
echo ""

# 7. Final summary
echo "=========================================="
echo "✅ SELF-HOSTED MCP SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Installation directory: $MCP_DIR"
echo ""
echo "🚀 Start services:"
echo "   cd $MCP_DIR"
echo "   ./start.sh"
echo ""
echo "🧪 Test services:"
echo "   ./test.sh"
echo ""
echo "📊 Check status:"
echo "   docker-compose ps"
echo ""
echo "📝 View logs:"
echo "   docker-compose logs -f"
echo "   docker-compose logs -f reddit-mcp"
echo ""
echo "🛑 Stop services:"
echo "   ./stop.sh"
echo ""
echo "🔧 What's configured:"
echo "   ✅ Reddit MCP (port 5000) - No auth needed"

if [[ "$has_creds" =~ ^[Yy]$ ]] && [ -f "$MCP_DIR/gmail-mcp/package.json" ]; then
    echo "   ✅ Gmail MCP (port 5001) - OAuth2 configured"
else
    echo "   ⏸️  Gmail MCP - Not configured"
fi

if [ -f "$MCP_DIR/.env.notion" ]; then
    echo "   ✅ Notion MCP (port 5002) - Token configured"
else
    echo "   ⏸️  Notion MCP - Not configured"
fi

echo ""
echo "📚 Documentation: MCP_SELF_HOSTED_GUIDE.md"
echo ""

read -p "Start services now? [y/N]: " start_now
if [[ "$start_now" =~ ^[Yy]$ ]]; then
    cd "$MCP_DIR"
    ./start.sh
    sleep 3
    ./test.sh
fi
