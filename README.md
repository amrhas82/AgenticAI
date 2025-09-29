# AI Agent Playground 🚀

A complete local AI agent playground for learning and experimentation. No API keys, no internet required after setup!

## Quick Start

1. **Prerequisites**: Docker, Docker Compose, Ollama
2. **Setup**: `./setup.sh`
3. **Run**: `docker-compose up`
4. **Access**: Open http://localhost:8501

## Full documentation in `/docs/` folder:
- [High Level Architecture](docs/HLA.md)
- [Setup Guide](docs/SETUP.md)
- [Technical Design](docs/HLD.md)

## Troubleshooting

### Docker Permission Issues
```bash
sudo usermod -aG docker $USER
newgrp docker