import os
import requests
from typing import Dict, List, Optional, Any
import json


class MCPClient:
    """
    Model Context Protocol (MCP) Client for Klavis AI integration
    
    Klavis MCP provides a standardized interface for AI agents to access
    various tools and resources reliably.
    
    Reference: https://github.com/Klavis-AI/klavis
    """
    
    def __init__(self, mcp_url: str | None = None):
        self.mcp_url = mcp_url or os.getenv("MCP_URL", "http://localhost:8080")
        self.api_key = os.getenv("MCP_API_KEY")
        self.timeout = 10
        self._session = requests.Session()
        
        # Set up default headers
        if self.api_key:
            self._session.headers.update({
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            })

    def update_url(self, mcp_url: str) -> None:
        """Update the MCP base URL at runtime."""
        self.mcp_url = mcp_url

    def get_status(self) -> str:
        """Get MCP connection status via simple HTTP GET"""
        try:
            resp = self._session.get(
                f"{self.mcp_url}/health",
                timeout=1.5
            )
            if resp.ok:
                return f"OK ({self.mcp_url})"
            return f"Unhealthy ({resp.status_code})"
        except Exception as e:
            return f"Not reachable: {e}"
    
    def list_tools(self) -> List[Dict[str, Any]]:
        """
        List all available tools from the MCP server
        
        Returns:
            List of tool definitions with name, description, and parameters
        """
        try:
            resp = self._session.get(
                f"{self.mcp_url}/api/tools",
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json().get("tools", [])
        except Exception as e:
            print(f"Error listing MCP tools: {e}")
            return []
    
    def call_tool(
        self,
        tool_name: str,
        parameters: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Call a specific tool via MCP
        
        Args:
            tool_name: Name of the tool to call
            parameters: Dictionary of parameters for the tool
        
        Returns:
            Tool execution result
        """
        try:
            payload = {
                "tool": tool_name,
                "parameters": parameters or {}
            }
            
            resp = self._session.post(
                f"{self.mcp_url}/api/tools/execute",
                json=payload,
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json()
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def list_resources(self) -> List[Dict[str, Any]]:
        """
        List all available resources (files, databases, etc.) from MCP
        
        Returns:
            List of resource definitions
        """
        try:
            resp = self._session.get(
                f"{self.mcp_url}/api/resources",
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json().get("resources", [])
        except Exception as e:
            print(f"Error listing MCP resources: {e}")
            return []
    
    def read_resource(self, resource_uri: str) -> Dict[str, Any]:
        """
        Read content from a specific resource
        
        Args:
            resource_uri: URI of the resource to read
        
        Returns:
            Resource content and metadata
        """
        try:
            resp = self._session.get(
                f"{self.mcp_url}/api/resources/read",
                params={"uri": resource_uri},
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_prompts(self) -> List[Dict[str, Any]]:
        """
        Get available prompt templates from MCP
        
        Returns:
            List of prompt templates
        """
        try:
            resp = self._session.get(
                f"{self.mcp_url}/api/prompts",
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json().get("prompts", [])
        except Exception as e:
            print(f"Error getting MCP prompts: {e}")
            return []
    
    def execute_prompt(
        self,
        prompt_name: str,
        arguments: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Execute a prompt template with arguments
        
        Args:
            prompt_name: Name of the prompt template
            arguments: Arguments to fill the template
        
        Returns:
            Rendered prompt result
        """
        try:
            payload = {
                "prompt": prompt_name,
                "arguments": arguments or {}
            }
            
            resp = self._session.post(
                f"{self.mcp_url}/api/prompts/execute",
                json=payload,
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json()
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def send_notification(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Send a notification to the MCP server
        
        Args:
            method: Notification method name
            params: Notification parameters
        
        Returns:
            Success boolean
        """
        try:
            payload = {
                "method": method,
                "params": params or {}
            }
            
            resp = self._session.post(
                f"{self.mcp_url}/api/notifications",
                json=payload,
                timeout=self.timeout
            )
            resp.raise_for_status()
            return True
            
        except Exception as e:
            print(f"Error sending MCP notification: {e}")
            return False
    
    def get_server_info(self) -> Dict[str, Any]:
        """
        Get information about the MCP server
        
        Returns:
            Server information including version, capabilities, etc.
        """
        try:
            resp = self._session.get(
                f"{self.mcp_url}/api/info",
                timeout=self.timeout
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def close(self):
        """Close the session"""
        self._session.close()