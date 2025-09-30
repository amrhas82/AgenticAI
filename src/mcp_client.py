import os
import requests


class MCPClient:
    def __init__(self, mcp_url: str | None = None):
        self.mcp_url = mcp_url or os.getenv("MCP_URL", "http://localhost:8080")

    def update_url(self, mcp_url: str) -> None:
        """Update the MCP base URL at runtime."""
        self.mcp_url = mcp_url

    def get_status(self) -> str:
        """Get MCP connection status via simple HTTP GET"""
        try:
            resp = requests.get(self.mcp_url, timeout=1.5)
            if resp.ok:
                return f"OK ({self.mcp_url})"
            return f"Unhealthy ({resp.status_code})"
        except Exception as e:
            return f"Not reachable: {e}"