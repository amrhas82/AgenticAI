#!/bin/bash
# Setup script for AI Agent Playground enhancements

echo "🚀 Setting up AI Agent Playground enhancements..."

# Create new directory structure
echo "📁 Creating directory structure..."
mkdir -p src/agents
mkdir -p src/ui
mkdir -p src/database
mkdir -p data/config

# Create __init__.py files for Python packages
touch src/agents/__init__.py
touch src/ui/__init__.py
touch src/database/__init__.py

echo "✅ Directory structure created"

# Create backup of existing files
echo "💾 Creating backups..."
if [ -f "src/app.py" ]; then
    cp src/app.py src/app.py.backup
    echo "   - Backed up app.py"
fi

if [ -f "src/vector_db.py" ]; then
    cp src/vector_db.py src/database/vector_db_legacy.py
    echo "   - Backed up vector_db.py"
fi

if [ -f "src/memory_manager.py" ]; then
    cp src/memory_manager.py src/memory_manager.py.backup
    echo "   - Backed up memory_manager.py"
fi

echo "✅ Backups created"

echo ""
echo "📋 Next steps:"
echo "1. Copy the artifact code files to:"
echo "   - src/agents/agent_system.py"
echo "   - src/database/enhanced_vector_db.py"
echo "   - src/ui/document_manager.py"
echo "   - src/ui/conversation_manager.py"
echo "   - src/utils/config_manager.py"
echo ""
echo "2. Replace src/app.py with the updated version"
echo ""
echo "3. Update requirements.txt if needed:"
echo "   pip install pandas numpy"
echo ""
echo "4. Restart your containers:"
echo "   docker compose down"
echo "   docker compose up -d --build"
echo ""
echo "✨ Setup script complete!"
