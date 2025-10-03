#!/bin/bash

# Setup script to auto-start Streamlit on boot

set -euo pipefail

echo "🚀 Setting up auto-start for AI Agent Playground..."
echo ""

# Get the current directory (project root)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create systemd service file
SERVICE_FILE="$HOME/.config/systemd/user/agentic-ai.service"

echo "Creating systemd service at: $SERVICE_FILE"

mkdir -p "$HOME/.config/systemd/user"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Agentic AI Streamlit Interface
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$HOME/.local/bin/streamlit run src/app.py --server.port=8501 --server.address=0.0.0.0
Restart=on-failure
RestartSec=5
StandardOutput=append:$PROJECT_DIR/logs/streamlit.log
StandardError=append:$PROJECT_DIR/logs/streamlit.log

# Environment variables
Environment="PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=default.target
EOF

echo "✅ Service file created"
echo ""

# Reload systemd user daemon
systemctl --user daemon-reload
echo "✅ Systemd daemon reloaded"
echo ""

# Enable the service (auto-start on boot)
systemctl --user enable agentic-ai.service
echo "✅ Auto-start enabled"
echo ""

# Enable lingering (allows user services to run without login)
sudo loginctl enable-linger $USER 2>/dev/null || echo "⚠️  Could not enable lingering (may need sudo)"
echo ""

echo "========================================"
echo "✅ AUTO-START CONFIGURED!"
echo "========================================"
echo ""
echo "Commands:"
echo "  Start now:   systemctl --user start agentic-ai"
echo "  Stop:        systemctl --user stop agentic-ai"
echo "  Status:      systemctl --user status agentic-ai"
echo "  Logs:        journalctl --user -u agentic-ai -f"
echo "  Disable:     systemctl --user disable agentic-ai"
echo ""
echo "After reboot, Streamlit will start automatically!"
echo "Access at: http://localhost:8501"
echo ""

# Ask if user wants to start now
read -p "Start Streamlit now? [y/N]: " start_now
if [[ "$start_now" =~ ^[Yy]$ ]]; then
    # Stop any existing streamlit processes
    pkill -f "streamlit run" 2>/dev/null || true
    sleep 2

    systemctl --user start agentic-ai
    sleep 3

    if systemctl --user is-active --quiet agentic-ai; then
        echo "✅ Streamlit is now running!"
        echo "Open: http://localhost:8501"
    else
        echo "❌ Failed to start. Check logs:"
        echo "   journalctl --user -u agentic-ai -n 50"
    fi
fi
