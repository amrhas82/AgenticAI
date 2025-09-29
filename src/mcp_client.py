import os
import requests


class MCPClient:
    def __init__(self):
        self.mcp_url = os.getenv("MCP_URL", "http://localhost:8080")

    def get_status(self) -> str:
        """Get MCP connection status via simple HTTP GET"""
        try:
            resp = requests.get(self.mcp_url, timeout=1.5)
            if resp.ok:
                return f"OK ({self.mcp_url})"
            return f"Unhealthy ({resp.status_code})"
        except Exception as e:
            return f"Not reachable: {e}"