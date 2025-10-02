#!/bin/bash

# Simple script to run the AI Agent Playground in native mode (no Docker)
# This is the simplest way to get started with local LLMs

set -euo pipefail

# Colors
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

info() { printf "%b[INFO]%b %s\n" "$YELLOW" "$RESET" "$1"; }
success() { printf "%b[SUCCESS]%b %s\n" "$GREEN" "$RESET" "$1"; }
error() { printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$1"; }

# Create logs directory
mkdir -p logs

info "Starting AI Agent Playground (Native Mode)..."
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    error "Python 3 is required but not installed!"
    echo "Please install Python 3.8+ and try again."
    exit 1
fi
success "Python 3 found: $(python3 --version)"

# Check Ollama
if ! command -v ollama &> /dev/null; then
    error "Ollama is not installed!"
    echo ""
    echo "Install Ollama with:"
    echo "  curl -fsSL https://ollama.ai/install.sh | sh"
    echo ""
    echo "Or use the menu script: ./menu.sh"
    exit 1
fi
success "Ollama found: $(which ollama)"

# Start Ollama if not running
if ! pgrep -f "ollama serve" > /dev/null; then
    info "Starting Ollama server..."
    OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve > logs/ollama.log 2>&1 &
    echo $! > logs/ollama.pid
    sleep 3
    
    if pgrep -f "ollama serve" > /dev/null; then
        success "Ollama started (PID: $(cat logs/ollama.pid))"
    else
        error "Failed to start Ollama"
        cat logs/ollama.log
        exit 1
    fi
else
    success "Ollama already running"
fi

# Check if Ollama API is responding
if curl -fsS http://localhost:11434/api/tags > /dev/null 2>&1; then
    success "Ollama API is responding"
else
    error "Ollama API is not responding at http://localhost:11434"
    exit 1
fi

# Check for models
info "Checking for installed models..."
MODEL_COUNT=$(ollama list | tail -n +2 | wc -l)

if [ "$MODEL_COUNT" -eq 0 ]; then
    echo ""
    error "No models installed!"
    echo ""
    echo "You need to install at least one model. Recommended options:"
    echo ""
    echo "  Small & Fast (1-3B parameters - BEST FOR CPU):"
    echo "    ollama pull llama3.2:1b          # General chat, very fast (1.3GB)"
    echo "    ollama pull deepseek-coder:1.3b  # Coding, very fast (776MB)"
    echo "    ollama pull qwen2.5-coder:1.5b   # Coding, excellent (986MB)"
    echo ""
    echo "  Medium (7-8B parameters):"
    echo "    ollama pull llama3               # General chat, better quality (4.7GB)"
    echo "    ollama pull mistral              # General chat, fast (4.1GB)"
    echo ""
    read -p "Pull deepseek-coder:1.3b now? (recommended for coding) [y/N]: " pull_choice
    if [ "$pull_choice" = "y" ] || [ "$pull_choice" = "Y" ]; then
        ollama pull deepseek-coder:1.3b
        ollama pull llama3.2:1b  # Also pull general chat model
        success "Models installed!"
    else
        echo "Please install a model manually and run this script again."
        exit 1
    fi
else
    success "Found $MODEL_COUNT model(s):"
    ollama list | tail -n +2
fi

echo ""

# Install Python dependencies if needed
if [ -f requirements.txt ]; then
    info "Checking Python dependencies..."
    if python3 -m pip show streamlit > /dev/null 2>&1; then
        success "Dependencies already installed"
    else
        info "Installing Python dependencies..."
        python3 -m pip install --user -r requirements.txt > logs/pip_install.log 2>&1
        success "Dependencies installed"
    fi
fi

# Create .env if missing
if [ ! -f .env ]; then
    info "Creating .env configuration..."
    cat > .env << 'EOF'
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://localhost:8080
EOF
    success ".env created"
fi

# Create data directories
mkdir -p data/{documents,conversations,uploads,db}

# Check if port 8501 is in use
if lsof -ti:8501 > /dev/null 2>&1; then
    error "Port 8501 is already in use!"
    echo "Existing process: PID $(lsof -ti:8501)"
    read -p "Kill existing process and continue? [y/N]: " kill_choice
    if [ "$kill_choice" = "y" ] || [ "$kill_choice" = "Y" ]; then
        kill $(lsof -ti:8501)
        sleep 2
    else
        exit 1
    fi
fi

# Start Streamlit
info "Starting Streamlit app..."

# Find streamlit command
STREAMLIT_CMD="$HOME/.local/bin/streamlit"
if [ ! -f "$STREAMLIT_CMD" ]; then
    STREAMLIT_CMD="$(which streamlit 2>/dev/null)"
    if [ -z "$STREAMLIT_CMD" ]; then
        # Try running via python module
        if python3 -m streamlit --version >/dev/null 2>&1; then
            STREAMLIT_CMD="python3 -m streamlit"
        else
            error "Streamlit not found. Please install: python3 -m pip install --user streamlit"
            exit 1
        fi
    fi
fi

echo ""
success "Starting at http://localhost:8501"
echo ""
echo "Logs:"
echo "  Ollama:    logs/ollama.log"
echo "  Streamlit: logs/streamlit.log"
echo ""
echo "To stop: Press Ctrl+C or run: ./menu.sh (option 5)"
echo ""

# Run streamlit (keep in foreground)
$STREAMLIT_CMD run src/app.py --server.port=8501 --server.address=0.0.0.0 2>&1 | tee logs/streamlit.log
