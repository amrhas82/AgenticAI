#!/bin/bash

echo "Setting up AI Agent Playground..."

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "Ollama not found. Please install Ollama first:"
    echo "Visit: https://ollama.ai/download"
    echo "Or run: curl -fsSL https://ollama.ai/install.sh | sh"
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env file from example"
fi

# Pull default models
echo "Pulling Ollama models (this may take a while)..."
ollama pull llama2
ollama pull mistral

# Build and start containers (THIS IS THE KEY - uses Docker, not local Python)
echo "Building and starting Docker containers..."
echo "This will handle all Python dependencies in isolation..."
docker-compose down  # Clean up any old containers
docker-compose build --no-cache  # Fresh build
docker-compose up -d

echo "Setup complete!"
echo "✅ Streamlit app: http://localhost:8501"
echo "✅ PostgreSQL: localhost:5432"
echo "✅ All dependencies handled in Docker containers"
echo ""
echo "To view logs: docker-compose logs -f streamlit-app"
echo "To stop: docker-compose down"