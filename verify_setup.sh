#!/bin/bash
# Quick verification script for AgenticAI setup
# Tests both native and docker environments

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         AgenticAI Setup Verification Script             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "ℹ️  $1"
}

# Check Python
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking Python Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    success "Python found: $PYTHON_VERSION"
    
    # Check if it's Python 3.13+
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 13) else 1)" 2>/dev/null; then
        info "Python 3.13+ detected - will use psycopg3"
    else
        info "Python < 3.13 detected - will use psycopg2-binary"
    fi
else
    error "Python 3 not found!"
    exit 1
fi

# Check critical packages
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checking Python Packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_package() {
    local package=$1
    if python3 -m pip list 2>/dev/null | grep -q "^$package "; then
        local version=$(python3 -m pip list 2>/dev/null | grep "^$package " | awk '{print $2}')
        success "$package ($version)"
        return 0
    else
        error "$package not installed"
        return 1
    fi
}

PACKAGES_OK=true
check_package "streamlit" || PACKAGES_OK=false
check_package "ollama" || PACKAGES_OK=false
check_package "numpy" || PACKAGES_OK=false
check_package "openai" || PACKAGES_OK=false

# Check psycopg (either version)
if python3 -m pip list 2>/dev/null | grep -qE "^psycopg2-binary |^psycopg "; then
    if python3 -m pip list 2>/dev/null | grep -q "^psycopg2-binary "; then
        version=$(python3 -m pip list 2>/dev/null | grep "^psycopg2-binary " | awk '{print $2}')
        success "psycopg2-binary ($version)"
    elif python3 -m pip list 2>/dev/null | grep -q "^psycopg "; then
        version=$(python3 -m pip list 2>/dev/null | grep "^psycopg " | awk '{print $2}')
        success "psycopg ($version)"
    fi
else
    error "Neither psycopg2-binary nor psycopg installed"
    PACKAGES_OK=false
fi

# Check imports
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Testing Critical Imports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_import() {
    local module=$1
    local name=$2
    if python3 -c "import $module" 2>/dev/null; then
        success "$name imports successfully"
        return 0
    else
        error "$name import failed"
        return 1
    fi
}

IMPORTS_OK=true
test_import "streamlit" "Streamlit" || IMPORTS_OK=false
test_import "ollama" "Ollama" || IMPORTS_OK=false
test_import "openai" "OpenAI" || IMPORTS_OK=false
test_import "numpy" "NumPy" || IMPORTS_OK=false

# Test psycopg import (try both)
if python3 -c "import psycopg2" 2>/dev/null; then
    success "psycopg2 imports successfully"
elif python3 -c "import psycopg" 2>/dev/null; then
    success "psycopg imports successfully"
else
    error "Neither psycopg2 nor psycopg can be imported"
    IMPORTS_OK=false
fi

# Test app modules
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Testing App Modules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APP_OK=true
if python3 -c "from src.database.enhanced_vector_db import EnhancedVectorDB" 2>/dev/null; then
    success "EnhancedVectorDB module loads"
else
    error "EnhancedVectorDB module failed to load"
    APP_OK=false
fi

if python3 -c "from src.vector_db import VectorDB" 2>/dev/null; then
    success "VectorDB module loads"
else
    error "VectorDB module failed to load"
    APP_OK=false
fi

if python3 -c "from src.api_key_manager import APIKeyManager" 2>/dev/null; then
    success "APIKeyManager module loads"
else
    error "APIKeyManager module failed to load"
    APP_OK=false
fi

if python3 -c "import sys; sys.path.insert(0, 'src'); from app import AIPlaygroundApp" 2>/dev/null; then
    success "Main app module loads"
else
    error "Main app module failed to load"
    APP_OK=false
fi

# Check Ollama
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Checking Ollama (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v ollama &> /dev/null; then
    success "Ollama is installed"
    
    # Check if Ollama service is running
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        success "Ollama service is running"
        
        # List available models
        models=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('models', [])))" 2>/dev/null || echo "0")
        if [ "$models" -gt 0 ]; then
            success "Ollama has $models model(s) available"
        else
            warn "Ollama is running but no models are installed"
            info "Install models with: ollama pull llama2"
        fi
    else
        warn "Ollama is installed but not running"
        info "Start Ollama with: ollama serve"
    fi
else
    warn "Ollama not installed (optional for local models)"
    info "Install from: https://ollama.ai/install.sh"
fi

# Check Docker
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Checking Docker (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v docker &> /dev/null; then
    success "Docker is installed"
    
    if docker info >/dev/null 2>&1; then
        success "Docker daemon is running"
        
        # Check Docker Compose
        if docker compose version >/dev/null 2>&1; then
            success "Docker Compose available"
        elif command -v docker-compose &> /dev/null; then
            success "docker-compose available"
        else
            warn "Docker Compose not found"
        fi
    else
        warn "Docker is installed but daemon not reachable"
        info "Start Docker Desktop or run: sudo systemctl start docker"
    fi
else
    warn "Docker not installed (optional for containerized setup)"
    info "Install from: https://docs.docker.com/get-docker/"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if $PACKAGES_OK && $IMPORTS_OK && $APP_OK; then
    echo ""
    success "All critical checks passed! ✨"
    echo ""
    info "Your environment is ready to run AgenticAI"
    echo ""
    echo "Next steps:"
    echo "  • Native mode: ./menu.sh -> Option 4 (Start Services)"
    echo "  • Docker mode:  ./menu.sh -> Option 2 (Docker Setup)"
    echo ""
else
    echo ""
    error "Some checks failed. Please review the output above."
    echo ""
    
    if ! $PACKAGES_OK; then
        info "Install missing packages:"
        echo "  python3 -m pip install --user -r requirements.txt"
    fi
    
    if ! $IMPORTS_OK || ! $APP_OK; then
        info "If imports are failing, try:"
        echo "  python3 -m pip install --user --force-reinstall -r requirements.txt"
    fi
    echo ""
    info "For more help, see: SETUP_FIXES_2025.md"
    echo ""
    exit 1
fi
