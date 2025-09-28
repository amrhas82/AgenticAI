# Complete Setup Guide

## 1. Install Prerequisites

### Zorin OS (Ubuntu-based)
```bash
# Install Docker
sudo apt update
sudo apt install docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh