"""
Klavis Strata MCP Client

This client integrates with Klavis Strata MCP router (Option 1: Self-hosted)
Provides unified access to multiple MCP services through a single endpoint.

Usage:
    from klavis_strata_client import StrataClient

    client = StrataClient()
    tools = client.list_tools()
    result = client.call_tool("reddit_get_hot_posts", {"subreddit": "python", "limit": 5})
"""

import os
import requests
from typing import Dict, Any, List, Optional
import logging

logger = logging.getLogger(__name__)


class StrataClient:
    """Client for Klavis Strata MCP router"""

    def __init__(
        self,
        strata_url: Optional[str] = None,
        fallback_urls: Optional[Dict[str, str]] = None,
        api_key: Optional[str] = None
    ):
        """
        Initialize Strata client

        Args:
            strata_url: URL of Strata router (default: from env STRATA_MCP_URL)
            fallback_urls: Dict of service name -> direct URL for fallback
            api_key: Klavis API key if required
        """
        self.use_strata = os.getenv("USE_STRATA", "false").lower() == "true"
        self.strata_url = strata_url or os.getenv("STRATA_MCP_URL", "http://localhost:8080")
        self.api_key = api_key or os.getenv("KLAVIS_API_KEY")

        # Fallback to direct service URLs if Strata is unavailable
        self.fallback_urls = fallback_urls or {
            "reddit": os.getenv("MCP_REDDIT_URL", "http://localhost:5000"),
            "gmail": os.getenv("MCP_GMAIL_URL", "http://localhost:5001"),
            "notion": os.getenv("MCP_NOTION_URL", "http://localhost:5002"),
        }

        # Check if Strata is available
        if self.use_strata:
            self._check_strata_availability()

    def _check_strata_availability(self) -> bool:
        """Check if Strata router is running"""
        try:
            response = requests.get(f"{self.strata_url}/health", timeout=2)
            if response.status_code == 200:
                logger.info("Strata router is available")
                return True
        except requests.exceptions.RequestException:
            logger.warning("Strata router not available, will use direct service URLs")
            self.use_strata = False
        return False

    def _get_headers(self) -> Dict[str, str]:
        """Get HTTP headers for requests"""
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def _determine_service_url(self, tool_name: str) -> str:
        """Determine which URL to use based on tool name"""
        if self.use_strata:
            return self.strata_url

        # Fallback to direct service URLs based on tool name prefix
        tool_lower = tool_name.lower()
        if "reddit" in tool_lower:
            return self.fallback_urls.get("reddit", self.strata_url)
        elif "gmail" in tool_lower or "email" in tool_lower:
            return self.fallback_urls.get("gmail", self.strata_url)
        elif "notion" in tool_lower:
            return self.fallback_urls.get("notion", self.strata_url)

        return self.strata_url

    def list_tools(self, service: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        List available tools

        Args:
            service: Optional service name to filter tools (e.g., "reddit", "gmail")

        Returns:
            List of available tools with their descriptions
        """
        if self.use_strata:
            # Query Strata for all tools
            url = f"{self.strata_url}/tools"
            if service:
                url += f"?service={service}"
        else:
            # Query individual services
            if service and service in self.fallback_urls:
                url = f"{self.fallback_urls[service]}/tools"
            else:
                # Get tools from all available services
                all_tools = []
                for svc_name, svc_url in self.fallback_urls.items():
                    try:
                        response = requests.get(
                            f"{svc_url}/tools",
                            headers=self._get_headers(),
                            timeout=5
                        )
                        if response.status_code == 200:
                            tools = response.json()
                            # Add service prefix to each tool
                            for tool in tools:
                                tool["service"] = svc_name
                            all_tools.extend(tools)
                    except requests.exceptions.RequestException as e:
                        logger.warning(f"Failed to get tools from {svc_name}: {e}")
                return all_tools

        try:
            response = requests.get(url, headers=self._get_headers(), timeout=5)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to list tools: {e}")
            return []

    def call_tool(
        self,
        tool_name: str,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Call an MCP tool

        Args:
            tool_name: Name of the tool to call (e.g., "reddit_get_hot_posts")
            parameters: Tool parameters as dictionary

        Returns:
            Tool execution result
        """
        service_url = self._determine_service_url(tool_name)

        try:
            response = requests.post(
                f"{service_url}/tools/{tool_name}",
                json=parameters,
                headers=self._get_headers(),
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to call tool {tool_name}: {e}")
            return {
                "error": str(e),
                "tool": tool_name,
                "parameters": parameters
            }

    def discover_categories(self) -> List[str]:
        """
        Discover available tool categories (Strata-specific feature)

        This is part of Strata's progressive discovery - it helps agents
        discover what types of tools are available before loading all tools.

        Returns:
            List of category names
        """
        if not self.use_strata:
            # Fallback: return service names
            return list(self.fallback_urls.keys())

        try:
            response = requests.get(
                f"{self.strata_url}/discover/categories",
                headers=self._get_headers(),
                timeout=5
            )
            response.raise_for_status()
            return response.json().get("categories", [])
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to discover categories: {e}")
            return list(self.fallback_urls.keys())

    def discover_actions(self, category: str) -> List[Dict[str, Any]]:
        """
        Discover actions within a category (Strata-specific feature)

        This is Strata's progressive discovery - agents can explore
        what actions are available in a category before executing.

        Args:
            category: Category name (e.g., "reddit", "gmail")

        Returns:
            List of available actions in the category
        """
        if not self.use_strata:
            # Fallback: return all tools for that service
            return self.list_tools(service=category)

        try:
            response = requests.get(
                f"{self.strata_url}/discover/{category}/actions",
                headers=self._get_headers(),
                timeout=5
            )
            response.raise_for_status()
            return response.json().get("actions", [])
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to discover actions for {category}: {e}")
            return []

    def health_check(self) -> Dict[str, Any]:
        """
        Check health of Strata and connected services

        Returns:
            Dict with status information
        """
        health = {
            "strata": "unknown",
            "services": {}
        }

        # Check Strata
        if self.use_strata:
            try:
                response = requests.get(f"{self.strata_url}/health", timeout=2)
                health["strata"] = "healthy" if response.status_code == 200 else "unhealthy"
            except requests.exceptions.RequestException:
                health["strata"] = "unavailable"

        # Check individual services
        for service_name, service_url in self.fallback_urls.items():
            try:
                response = requests.get(f"{service_url}/health", timeout=2)
                health["services"][service_name] = {
                    "status": "healthy" if response.status_code == 200 else "unhealthy",
                    "url": service_url
                }
            except requests.exceptions.RequestException:
                health["services"][service_name] = {
                    "status": "unavailable",
                    "url": service_url
                }

        return health


# Example usage and helper functions
def create_default_client() -> StrataClient:
    """Create a Strata client with default configuration from environment"""
    return StrataClient()


def test_connection():
    """Test connection to Strata and MCP services"""
    client = create_default_client()
    print("Health Check:")
    print(client.health_check())

    print("\nAvailable Categories:")
    categories = client.discover_categories()
    print(categories)

    print("\nAvailable Tools:")
    tools = client.list_tools()
    for tool in tools[:5]:  # Show first 5 tools
        print(f"  - {tool.get('name', 'unknown')}: {tool.get('description', 'No description')}")


if __name__ == "__main__":
    # Run test if executed directly
    test_connection()
