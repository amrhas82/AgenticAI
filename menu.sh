#!/bin/bash
mkdir -p ./logs

# Interactive Menu Script for AI Agent Playground
# This script provides a simple menu to manage your local AI interface

set -euo pipefail

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# Logging setup
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
MAIN_LOG="$LOG_DIR/menu_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG"
}

info() {
    printf "%b[INFO] %s%b\n" "$CYAN" "$1" "$RESET" | tee -a "$MAIN_LOG"
}

success() {
    printf "%b[SUCCESS] %s%b\n" "$GREEN" "$1" "$RESET" | tee -a "$MAIN_LOG"
}

warn() {
    printf "%b[WARN] %s%b\n" "$YELLOW" "$1" "$RESET" | tee -a "$MAIN_LOG"
}

error() {
    printf "%b[ERROR] %s%b\n" "$RED" "$1" "$RESET" | tee -a "$MAIN_LOG"
}

# Banner
show_banner() {
    clear
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║         🤖 AI AGENT PLAYGROUND - MENU SYSTEM 🤖          ║
║                                                          ║
║              Simple Local AI Interface                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

# Check if Docker is available
check_docker() {
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Option 1: Quick Setup (Native Mode - No Docker)
quick_setup_native() {
    info "Starting Quick Setup (Native Mode - No Docker)..."
    log "Installation paths will be logged to: $MAIN_LOG"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not found!"
        echo "Please install Python 3.8+ and try again."
        return 1
    fi
    
    PYTHON_PATH=$(which python3)
    PYTHON_VERSION=$(python3 --version)
    success "Python found at: $PYTHON_PATH"
    log "Python version: $PYTHON_VERSION"
    
    # Check/Install Ollama
    if ! command -v ollama &> /dev/null; then
        warn "Ollama not found. Installing..."
        if curl -fsSL https://ollama.ai/install.sh | sh; then
            OLLAMA_PATH=$(which ollama)
            success "Ollama installed at: $OLLAMA_PATH"
            log "Ollama installation path: $OLLAMA_PATH"
        else
            error "Failed to install Ollama"
            return 1
        fi
    else
        OLLAMA_PATH=$(which ollama)
        success "Ollama already installed at: $OLLAMA_PATH"
        log "Ollama path: $OLLAMA_PATH"
    fi
    
    # Install Python dependencies
    info "Installing Python dependencies..."
    # Use python3 -m pip to ensure we use the right pip
    if python3 -m pip install --user -r requirements.txt > "$LOG_DIR/pip_install.log" 2>&1; then
        success "Python dependencies installed"
        log "Pip packages installed. Details in: $LOG_DIR/pip_install.log"
    else
        error "Failed to install dependencies. Check $LOG_DIR/pip_install.log"
        return 1
    fi
    
    # Create .env file
    if [ ! -f .env ]; then
        info "Creating .env configuration file..."
        cat > .env << 'ENVEOF'
OLLAMA_HOST=http://localhost:11434
EMBED_MODEL=nomic-embed-text
EMBED_DIM=768
MCP_URL=http://localhost:8080
ENVEOF
        success ".env file created at: $(pwd)/.env"
        log "Environment file location: $(pwd)/.env"
    else
        info ".env file already exists"
    fi
    
    # Create data directories
    mkdir -p data/{documents,conversations,uploads,db}
    success "Data directories created at: $(pwd)/data/"
    log "Data directory structure:"
    log "  - Documents: $(pwd)/data/documents"
    log "  - Conversations: $(pwd)/data/conversations"
    log "  - Uploads: $(pwd)/data/uploads"
    log "  - Database: $(pwd)/data/db"
    
    success "Native setup complete!"
    echo ""
    info "Log file saved at: $MAIN_LOG"
    echo ""
    read -p "Press Enter to return to menu..."
}

# Option 2: Docker Setup
docker_setup() {
    info "Starting Docker Setup..."
    
    if ! check_docker; then
        error "Docker is not available!"
        echo "Please install Docker Desktop or Docker Engine first."
        echo "Visit: https://docs.docker.com/get-docker/"
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    success "Docker is available"
    
    info "Running setup.sh..."
    if bash setup.sh 2>&1 | tee "$LOG_DIR/docker_setup.log"; then
        success "Docker setup complete"
        log "Docker setup log saved to: $LOG_DIR/docker_setup.log"
    else
        error "Docker setup failed. Check $LOG_DIR/docker_setup.log"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Option 3: Health Check
health_check() {
    info "Running Health Check..."
    
    local health_log="$LOG_DIR/health_check_$(date +%Y%m%d_%H%M%S).log"
    
    echo "=== System Health Check ===" | tee "$health_log"
    echo "" | tee -a "$health_log"
    
    # Check Ollama
    echo "1. Checking Ollama..." | tee -a "$health_log"
    if command -v ollama &> /dev/null; then
        OLLAMA_PATH=$(which ollama)
        success "✓ Ollama installed at: $OLLAMA_PATH" | tee -a "$health_log"
        
        if pgrep -f "ollama serve" > /dev/null; then
            success "✓ Ollama service is running" | tee -a "$health_log"
            echo "  PID: $(pgrep -f 'ollama serve')" | tee -a "$health_log"
        else
            warn "✗ Ollama service is NOT running" | tee -a "$health_log"
        fi
        
        if curl -fsS http://localhost:11434/api/tags > /dev/null 2>&1; then
            success "✓ Ollama API is responding" | tee -a "$health_log"
            echo "  Available models:" | tee -a "$health_log"
            ollama list 2>/dev/null | tee -a "$health_log" || echo "  (none)" | tee -a "$health_log"
        else
            warn "✗ Ollama API is not responding" | tee -a "$health_log"
        fi
    else
        error "✗ Ollama is NOT installed" | tee -a "$health_log"
    fi
    
    echo "" | tee -a "$health_log"
    
    # Check Streamlit
    echo "2. Checking Streamlit..." | tee -a "$health_log"
    if curl -fsS http://localhost:8501/_stcore/health > /dev/null 2>&1; then
        success "✓ Streamlit is running at http://localhost:8501" | tee -a "$health_log"
        STREAMLIT_PID=$(lsof -ti:8501 2>/dev/null || echo "unknown")
        echo "  PID: $STREAMLIT_PID" | tee -a "$health_log"
    else
        warn "✗ Streamlit is NOT running" | tee -a "$health_log"
    fi
    
    echo "" | tee -a "$health_log"
    
    # Check Docker (if available)
    echo "3. Checking Docker..." | tee -a "$health_log"
    if check_docker; then
        success "✓ Docker is available" | tee -a "$health_log"
        echo "  Docker version: $(docker --version)" | tee -a "$health_log"
        echo "  Running containers:" | tee -a "$health_log"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tee -a "$health_log" || echo "  (none)" | tee -a "$health_log"
    else
        info "  Docker is not available (not required for native mode)" | tee -a "$health_log"
    fi
    
    echo "" | tee -a "$health_log"
    
    # Check Python environment
    echo "4. Checking Python environment..." | tee -a "$health_log"
    if command -v python3 &> /dev/null; then
        success "✓ Python 3 installed: $(python3 --version)" | tee -a "$health_log"
        echo "  Location: $(which python3)" | tee -a "$health_log"
    else
        error "✗ Python 3 is NOT installed" | tee -a "$health_log"
    fi
    
    echo "" | tee -a "$health_log"
    
    # Check data directories
    echo "5. Checking data directories..." | tee -a "$health_log"
    for dir in data/documents data/conversations data/uploads data/db; do
        if [ -d "$dir" ]; then
            success "✓ $dir exists" | tee -a "$health_log"
            echo "  Path: $(pwd)/$dir" | tee -a "$health_log"
        else
            warn "✗ $dir does not exist" | tee -a "$health_log"
        fi
    done
    
    echo "" | tee -a "$health_log"
    echo "=== Health check complete ===" | tee -a "$health_log"
    info "Health check log saved to: $health_log"
    
    read -p "Press Enter to return to menu..."
}

# Option 4: Start Services (Native Mode)
start_services_native() {
    info "Starting services in Native Mode..."
    
    # Start Ollama if not running
    if ! pgrep -f "ollama serve" > /dev/null; then
        info "Starting Ollama server..."
        OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve > "$LOG_DIR/ollama.log" 2>&1 &
        OLLAMA_PID=$!
        echo $OLLAMA_PID > "$LOG_DIR/ollama.pid"
        sleep 3
        
        if pgrep -f "ollama serve" > /dev/null; then
            success "Ollama started (PID: $(cat $LOG_DIR/ollama.pid))"
            log "Ollama log: $LOG_DIR/ollama.log"
        else
            error "Failed to start Ollama. Check $LOG_DIR/ollama.log"
        fi
    else
        success "Ollama is already running"
    fi
    
    # Check if port 8501 is in use
    if lsof -ti:8501 > /dev/null 2>&1; then
        warn "Port 8501 is already in use"
        OLD_PID=$(lsof -ti:8501)
        echo "Existing process PID: $OLD_PID"
        read -p "Kill existing process and restart? (y/n): " kill_choice
        if [ "$kill_choice" = "y" ]; then
            kill $OLD_PID 2>/dev/null || true
            sleep 2
        else
            read -p "Press Enter to return to menu..."
            return
        fi
    fi
    
    # Start Streamlit
    info "Starting Streamlit app..."
    # Use full path or python3 -m streamlit to ensure we find it
    STREAMLIT_CMD="$HOME/.local/bin/streamlit"
    if [ ! -f "$STREAMLIT_CMD" ]; then
        STREAMLIT_CMD="streamlit"
    fi
    nohup $STREAMLIT_CMD run src/app.py --server.port=8501 --server.address=0.0.0.0 > "$LOG_DIR/streamlit.log" 2>&1 &
    STREAMLIT_PID=$!
    echo $STREAMLIT_PID > "$LOG_DIR/streamlit.pid"
    
    sleep 5
    
    if curl -fsS http://localhost:8501/_stcore/health > /dev/null 2>&1; then
        success "Streamlit started successfully!"
        success "Access the UI at: http://localhost:8501"
        log "Streamlit PID: $(cat $LOG_DIR/streamlit.pid)"
        log "Streamlit log: $LOG_DIR/streamlit.log"
        echo ""
        info "Log files:"
        echo "  - Ollama: $LOG_DIR/ollama.log"
        echo "  - Streamlit: $LOG_DIR/streamlit.log"
        echo "  - PIDs saved in: $LOG_DIR/"
    else
        error "Failed to start Streamlit. Check $LOG_DIR/streamlit.log"
        tail -n 20 "$LOG_DIR/streamlit.log"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Option 5: Stop Services
stop_services() {
    info "Stopping services..."
    
    # Stop Streamlit
    if [ -f "$LOG_DIR/streamlit.pid" ]; then
        PID=$(cat "$LOG_DIR/streamlit.pid")
        if kill $PID 2>/dev/null; then
            success "Stopped Streamlit (PID: $PID)"
            rm "$LOG_DIR/streamlit.pid"
        fi
    fi
    
    if lsof -ti:8501 > /dev/null 2>&1; then
        warn "Streamlit still running on port 8501, force killing..."
        kill $(lsof -ti:8501) 2>/dev/null || true
    fi
    
    # Stop Ollama
    if [ -f "$LOG_DIR/ollama.pid" ]; then
        PID=$(cat "$LOG_DIR/ollama.pid")
        if kill $PID 2>/dev/null; then
            success "Stopped Ollama (PID: $PID)"
            rm "$LOG_DIR/ollama.pid"
        fi
    fi
    
    # Stop Docker containers if available
    if check_docker && [ -f docker-compose.yml ]; then
        info "Stopping Docker containers..."
        if docker compose down 2>&1 | tee -a "$MAIN_LOG"; then
            success "Docker containers stopped"
        fi
    fi
    
    success "All services stopped"
    read -p "Press Enter to return to menu..."
}

# Option 6: Restart Docker
restart_docker() {
    if ! check_docker; then
        error "Docker is not available!"
        read -p "Press Enter to return to menu..."
        return
    fi
    
    info "Restarting Docker containers..."
    
    if [ -f docker-compose.yml ]; then
        docker compose restart 2>&1 | tee "$LOG_DIR/docker_restart.log"
        success "Docker containers restarted"
        log "Docker restart log: $LOG_DIR/docker_restart.log"
    else
        error "docker-compose.yml not found"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Option 7: View Logs
view_logs() {
    info "Available log files:"
    echo ""
    
    if [ -d "$LOG_DIR" ]; then
        local log_files=($(ls -t "$LOG_DIR"/*.log 2>/dev/null))
        
        if [ ${#log_files[@]} -eq 0 ]; then
            warn "No log files found in $LOG_DIR"
            read -p "Press Enter to return to menu..."
            return
        fi
        
        for i in "${!log_files[@]}"; do
            echo "$((i+1)). ${log_files[$i]}"
        done
        
        echo "0. Return to menu"
        echo ""
        read -p "Select a log file to view (0-${#log_files[@]}): " log_choice
        
        if [ "$log_choice" -eq 0 ] 2>/dev/null; then
            return
        elif [ "$log_choice" -ge 1 ] && [ "$log_choice" -le ${#log_files[@]} ] 2>/dev/null; then
            local selected_log="${log_files[$((log_choice-1))]}"
            info "Viewing: $selected_log"
            echo ""
            less "$selected_log" || cat "$selected_log"
        else
            error "Invalid selection"
        fi
    else
        warn "Log directory not found: $LOG_DIR"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Option 8: Install/Pull Ollama Models
manage_models() {
    if ! command -v ollama &> /dev/null; then
        error "Ollama is not installed!"
        read -p "Press Enter to return to menu..."
        return
    fi
    
    info "Current models:"
    ollama list || warn "No models installed or Ollama not running"
    echo ""
    
    echo "Recommended models for local AI:"
    echo "  1. llama3.2 (small, fast, 3B params)"
    echo "  2. llama3.2:1b (tiny, very fast, 1B params)"
    echo "  3. qwen2.5-coder:1.5b (code-focused, tiny)"
    echo "  4. phi3.5 (small, 3.8B params)"
    echo "  5. Custom model name"
    echo "  0. Return to menu"
    echo ""
    read -p "Select a model to pull (0-5): " model_choice
    
    case $model_choice in
        1) MODEL="llama3.2" ;;
        2) MODEL="llama3.2:1b" ;;
        3) MODEL="qwen2.5-coder:1.5b" ;;
        4) MODEL="phi3.5" ;;
        5) read -p "Enter model name: " MODEL ;;
        0) return ;;
        *) error "Invalid selection"; read -p "Press Enter to return to menu..."; return ;;
    esac
    
    info "Pulling model: $MODEL"
    if ollama pull "$MODEL" 2>&1 | tee "$LOG_DIR/model_pull_$(date +%Y%m%d_%H%M%S).log"; then
        success "Model $MODEL pulled successfully!"
    else
        error "Failed to pull model $MODEL"
    fi
    
    read -p "Press Enter to return to menu..."
}

# Option 9: System Info
system_info() {
    info "System Information"
    echo ""
    
    echo "=== Installation Paths ===" | tee "$LOG_DIR/system_info.log"
    echo "Working directory: $(pwd)" | tee -a "$LOG_DIR/system_info.log"
    echo "Python: $(which python3 2>/dev/null || echo 'not found')" | tee -a "$LOG_DIR/system_info.log"
    echo "Ollama: $(which ollama 2>/dev/null || echo 'not found')" | tee -a "$LOG_DIR/system_info.log"
    echo "Docker: $(which docker 2>/dev/null || echo 'not found')" | tee -a "$LOG_DIR/system_info.log"
    STREAMLIT_PATH=$(which streamlit 2>/dev/null || echo "$HOME/.local/bin/streamlit")
    echo "Streamlit: $STREAMLIT_PATH" | tee -a "$LOG_DIR/system_info.log"
    echo "" | tee -a "$LOG_DIR/system_info.log"
    
    echo "=== Data Locations ===" | tee -a "$LOG_DIR/system_info.log"
    echo "Logs: $(pwd)/$LOG_DIR" | tee -a "$LOG_DIR/system_info.log"
    echo "Documents: $(pwd)/data/documents" | tee -a "$LOG_DIR/system_info.log"
    echo "Conversations: $(pwd)/data/conversations" | tee -a "$LOG_DIR/system_info.log"
    echo "Uploads: $(pwd)/data/uploads" | tee -a "$LOG_DIR/system_info.log"
    echo "Database: $(pwd)/data/db" | tee -a "$LOG_DIR/system_info.log"
    echo "" | tee -a "$LOG_DIR/system_info.log"
    
    echo "=== Running Services ===" | tee -a "$LOG_DIR/system_info.log"
    if pgrep -f "ollama serve" > /dev/null; then
        echo "Ollama: RUNNING (PID: $(pgrep -f 'ollama serve'))" | tee -a "$LOG_DIR/system_info.log"
    else
        echo "Ollama: NOT RUNNING" | tee -a "$LOG_DIR/system_info.log"
    fi
    
    if lsof -ti:8501 > /dev/null 2>&1; then
        echo "Streamlit: RUNNING (PID: $(lsof -ti:8501))" | tee -a "$LOG_DIR/system_info.log"
    else
        echo "Streamlit: NOT RUNNING" | tee -a "$LOG_DIR/system_info.log"
    fi
    
    if check_docker; then
        echo "Docker: AVAILABLE" | tee -a "$LOG_DIR/system_info.log"
        docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tee -a "$LOG_DIR/system_info.log"
    else
        echo "Docker: NOT AVAILABLE" | tee -a "$LOG_DIR/system_info.log"
    fi
    
    info "System info saved to: $LOG_DIR/system_info.log"
    
    read -p "Press Enter to return to menu..."
}

# Option 10: Troubleshooting
troubleshooting() {
    info "Running comprehensive troubleshooting..."
    
    local ts_log="$LOG_DIR/troubleshooting_$(date +%Y%m%d_%H%M%S).log"
    
    {
        echo "=== TROUBLESHOOTING REPORT ==="
        echo "Generated: $(date)"
        echo ""
        
        echo "1. System Requirements"
        echo "   Python: $(python3 --version 2>&1)"
        echo "   Pip: $(python3 -m pip --version 2>&1)"
        echo "   Docker: $(docker --version 2>&1 || echo 'not installed')"
        echo "   Ollama: $(ollama --version 2>&1 || echo 'not installed')"
        echo ""
        
        echo "2. Port Status"
        echo "   Port 8501 (Streamlit): $(lsof -ti:8501 > /dev/null 2>&1 && echo 'IN USE' || echo 'FREE')"
        echo "   Port 11434 (Ollama): $(lsof -ti:11434 > /dev/null 2>&1 && echo 'IN USE' || echo 'FREE')"
        echo "   Port 5432 (PostgreSQL): $(lsof -ti:5432 > /dev/null 2>&1 && echo 'IN USE' || echo 'FREE')"
        echo ""
        
        echo "3. Service Connectivity"
        if curl -fsS http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "   Ollama API: ✓ REACHABLE"
        else
            echo "   Ollama API: ✗ NOT REACHABLE"
        fi
        
        if curl -fsS http://localhost:8501/_stcore/health > /dev/null 2>&1; then
            echo "   Streamlit: ✓ REACHABLE"
        else
            echo "   Streamlit: ✗ NOT REACHABLE"
        fi
        echo ""
        
        echo "4. File System Check"
        for file in src/app.py requirements.txt .env docker-compose.yml; do
            if [ -f "$file" ]; then
                echo "   ✓ $file exists"
            else
                echo "   ✗ $file MISSING"
            fi
        done
        echo ""
        
        echo "5. Recent Errors in Logs"
        if [ -f "$LOG_DIR/streamlit.log" ]; then
            echo "   Recent Streamlit errors:"
            grep -i "error\|exception\|failed" "$LOG_DIR/streamlit.log" 2>/dev/null | tail -n 5 | sed 's/^/     /' || echo "     (none)"
        fi
        echo ""
        
        echo "6. Recommendations"
        if ! command -v ollama &> /dev/null; then
            echo "   ⚠ Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh"
        fi
        if ! pgrep -f "ollama serve" > /dev/null; then
            echo "   ⚠ Start Ollama: Run option 4 from menu or 'ollama serve'"
        fi
        if ! curl -fsS http://localhost:8501/_stcore/health > /dev/null 2>&1; then
            echo "   ⚠ Start Streamlit: Run option 4 from menu"
        fi
        
        echo ""
        echo "=== END OF REPORT ==="
        
    } | tee "$ts_log"
    
    success "Troubleshooting report saved to: $ts_log"
    
    read -p "Press Enter to return to menu..."
}

# Main menu
main_menu() {
    while true; do
        show_banner
        
        echo "📋 Main Menu:"
        echo ""
        echo "  Setup & Installation:"
        echo "    1) Quick Setup (Native - No Docker)"
        echo "    2) Docker Setup (Full)"
        echo ""
        echo "  Service Management:"
        echo "    3) Health Check"
        echo "    4) Start Services (Native Mode)"
        echo "    5) Stop All Services"
        echo "    6) Restart Docker Containers"
        echo ""
        echo "  Utilities:"
        echo "    7) View Logs"
        echo "    8) Install/Pull Ollama Models"
        echo "    9) System Information"
        echo "   10) Run Troubleshooting"
        echo ""
        echo "    0) Exit"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "Select an option (0-10): " choice
        
        case $choice in
            1) quick_setup_native ;;
            2) docker_setup ;;
            3) health_check ;;
            4) start_services_native ;;
            5) stop_services ;;
            6) restart_docker ;;
            7) view_logs ;;
            8) manage_models ;;
            9) system_info ;;
            10) troubleshooting ;;
            0) 
                info "Exiting menu..."
                exit 0
                ;;
            *)
                error "Invalid option. Please select 0-10."
                sleep 2
                ;;
        esac
    done
}

# Run main menu
main_menu
