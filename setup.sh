#!/bin/bash

echo "🚀 Setting up AI Agent Playground..."

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    echo "For Zorin OS (Ubuntu-based):"
    echo "sudo apt update && sudo apt install docker.io docker-compose"
    echo "sudo usermod -aG docker $USER && newgrp docker"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker daemon not running. Starting Docker..."
    sudo systemctl start docker
    sleep 3
fi

# Check if user is in docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    echo "⚠️  Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "✅ Please log out and log back in, or run: newgrp docker"
    exit 1
fi

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama not found. Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then


# Build and start containers
echo "🐳 Building and starting Docker containers..."
docker-compose down  # Clean up any old containers
docker-compose build --no-cache  # Fresh build

if docker-compose up -d; then
    echo "✅ Setup complete!"
    echo ""
    echo "🌐 Streamlit app: http://localhost:8501"
    echo "🗄️  PostgreSQL: localhost:5432"
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs: docker-compose logs -f streamlit-app"
    echo "   Stop services: docker-compose down"
    echo "   Restart: docker-compose restart"
else
    echo "❌ Docker compose failed. Check the errors above."
    exit 1
fi