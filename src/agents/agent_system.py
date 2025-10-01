from abc import ABC, abstractmethod
from typing import List, Dict, Optional, Any
from dataclasses import dataclass
import json


@dataclass
class AgentConfig:
    """Configuration for an agent"""
    name: str
    system_prompt: str
    temperature: float = 0.7
    max_tokens: int = 2000
    tools: List[str] = None
    
    def __post_init__(self):
        if self.tools is None:
            self.tools = []


class Tool(ABC):
    """Base class for agent tools"""
    
    @abstractmethod
    def name(self) -> str:
        pass
    
    @abstractmethod
    def description(self) -> str:
        pass
    
    @abstractmethod
    def execute(self, **kwargs) -> Any:
        pass
    
    def to_dict(self) -> Dict:
        return {
            "name": self.name(),
            "description": self.description()
        }


class SearchTool(Tool):
    """Tool for searching vector database"""
    
    def __init__(self, vector_db):
        self.vector_db = vector_db
    
    def name(self) -> str:
        return "search_documents"
    
    def description(self) -> str:
        return "Search through uploaded documents for relevant information. Use this when user asks about document content."
    
    def execute(self, query: str, limit: int = 5) -> List[str]:
        return self.vector_db.search_similar(query, limit)


class CodeExecutorTool(Tool):
    """Tool for executing Python code safely"""
    
    def name(self) -> str:
        return "execute_code"
    
    def description(self) -> str:
        return "Execute Python code in a sandboxed environment. Use for calculations, data processing, or demonstrations."
    
    def execute(self, code: str) -> Dict[str, Any]:
        """Execute code and return results safely"""
        import sys
        from io import StringIO
        
        # Capture stdout
        old_stdout = sys.stdout
        sys.stdout = StringIO()
        
        result = {
            "success": False,
            "output": "",
            "error": None
        }
        
        try:
            # Create restricted namespace
            namespace = {
                "__builtins__": {
                    "print": print,
                    "len": len,
                    "range": range,
                    "str": str,
                    "int": int,
                    "float": float,
                    "list": list,
                    "dict": dict,
                    "set": set,
                    "tuple": tuple,
                    "sum": sum,
                    "max": max,
                    "min": min,
                    "abs": abs,
                    "round": round,
                    "sorted": sorted,
                }
            }
            
            # Execute code
            exec(code, namespace)
            
            # Get output
            result["output"] = sys.stdout.getvalue()
            result["success"] = True
            
        except Exception as e:
            result["error"] = str(e)
        finally:
            sys.stdout = old_stdout
        
        return result


class MemoryTool(Tool):
    """Tool for accessing conversation history"""
    
    def __init__(self, memory_manager):
        self.memory_manager = memory_manager
    
    def name(self) -> str:
        return "recall_conversation"
    
    def description(self) -> str:
        return "Recall previous conversations or specific topics discussed earlier."
    
    def execute(self, query: str = None) -> List[Dict]:
        conversations = self.memory_manager.load_conversations()
        if query:
            # Simple keyword search
            filtered = []
            for conv in conversations:
                for msg in conv.get("messages", []):
                    if query.lower() in msg.get("content", "").lower():
                        filtered.append(conv)
                        break
            return filtered[-5:]  # Last 5 matching
        return conversations[-5:]  # Last 5 conversations


class Agent:
    """Enhanced agent with tool support"""
    
    def __init__(self, config: AgentConfig, tools: Optional[List[Tool]] = None):
        self.config = config
        self.tools = {tool.name(): tool for tool in (tools or [])}
        self.conversation_history: List[Dict] = []
    
    def add_tool(self, tool: Tool):
        """Add a tool to the agent"""
        self.tools[tool.name()] = tool
    
    def get_system_prompt(self) -> str:
        """Get system prompt with tool descriptions"""
        prompt = self.config.system_prompt
        
        if self.tools:
            prompt += "\n\nYou have access to the following tools:\n"
            for tool in self.tools.values():
                prompt += f"\n- {tool.name()}: {tool.description()}"
            
            prompt += "\n\nTo use a tool, respond with JSON in this format:"
            prompt += '\n{"tool": "tool_name", "arguments": {"arg1": "value1"}}'
        
        return prompt
    
    def process_message(self, message: str, llm_client) -> Dict[str, Any]:
        """Process a message with potential tool usage"""
        
        # Add user message to history
        self.conversation_history.append({
            "role": "user",
            "content": message
        })
        
        # Generate response with system prompt
        system_msg = self.get_system_prompt()
        augmented_message = f"{system_msg}\n\nUser: {message}"
        
        # Get LLM response
        response = llm_client.generate_response(
            augmented_message,
            self.conversation_history[:-1],
            model=self.config.name
        )
        
        # Check if response is a tool call
        tool_result = None
        if response.strip().startswith("{"):
            try:
                tool_call = json.loads(response.strip())
                if "tool" in tool_call and tool_call["tool"] in self.tools:
                    tool = self.tools[tool_call["tool"]]
                    args = tool_call.get("arguments", {})
                    tool_result = tool.execute(**args)
                    
                    # Generate final response with tool result
                    tool_context = f"\n\nTool '{tool.name()}' returned: {json.dumps(tool_result, indent=2)}"
                    final_prompt = f"{system_msg}{tool_context}\n\nUser: {message}\n\nProvide a natural language response using the tool result."
                    
                    response = llm_client.generate_response(
                        final_prompt,
                        self.conversation_history[:-1],
                        model=self.config.name
                    )
            except json.JSONDecodeError:
                pass  # Not a tool call, continue with normal response
        
        # Add assistant response to history
        self.conversation_history.append({
            "role": "assistant",
            "content": response
        })
        
        return {
            "response": response,
            "tool_used": tool_result is not None,
            "tool_result": tool_result
        }
    
    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []


class AgentRegistry:
    """Registry for managing multiple agents"""
    
    def __init__(self):
        self.agents: Dict[str, Agent] = {}
    
    def register(self, agent: Agent):
        """Register an agent"""
        self.agents[agent.config.name] = agent
    
    def get(self, name: str) -> Optional[Agent]:
        """Get agent by name"""
        return self.agents.get(name)
    
    def list_agents(self) -> List[str]:
        """List all registered agents"""
        return list(self.agents.keys())
    
    def create_default_agents(self, vector_db, memory_manager) -> None:
        """Create default set of agents"""
        
        # General Chat Agent
        general_agent = Agent(
            AgentConfig(
                name="General Chat",
                system_prompt="You are a helpful, friendly AI assistant. Engage in natural conversation and help with a wide variety of tasks.",
                temperature=0.7
            )
        )
        self.register(general_agent)
        
        # RAG Assistant
        rag_agent = Agent(
            AgentConfig(
                name="RAG Assistant",
                system_prompt=(
                    "You are a research assistant specialized in finding and synthesizing information from documents. "
                    "Always cite which documents or chunks you're referencing. "
                    "If information isn't in the documents, clearly state that."
                ),
                temperature=0.5
            ),
            tools=[SearchTool(vector_db), MemoryTool(memory_manager)]
        )
        self.register(rag_agent)
        
        # Code Assistant
        code_agent = Agent(
            AgentConfig(
                name="Coder (DeepSeek style)",
                system_prompt=(
                    "You are a meticulous coding assistant inspired by DeepSeek's reasoning approach. "
                    "Your process: 1) Understand requirements, 2) Plan the solution, 3) Write clean code, "
                    "4) Explain your approach, 5) Suggest tests. "
                    "You can execute Python code to verify solutions. "
                    "Prefer standard library and minimal dependencies."
                ),
                temperature=0.3
            ),
            tools=[CodeExecutorTool()]
        )
        self.register(code_agent)
        
        # Researcher Agent
        research_agent = Agent(
            AgentConfig(
                name="Research Assistant",
                system_prompt=(
                    "You are a thorough research assistant. Break down complex topics into clear components. "
                    "Search through available documents, synthesize information from multiple sources, "
                    "and present findings in a structured way. Always cite your sources."
                ),
                temperature=0.4
            ),
            tools=[SearchTool(vector_db), MemoryTool(memory_manager)]
        )
        self.register(research_agent)


# Example usage in app.py:
"""
# In AIPlaygroundApp.__init__():
self.agent_registry = AgentRegistry()
self.agent_registry.create_default_agents(self.vector_db, self.memory)

# In display_chat():
current_agent = self.agent_registry.get(st.session_state.current_agent)
if current_agent:
    result = current_agent.process_message(prompt, self.ollama)
    response = result["response"]
    if result["tool_used"]:
        st.info(f"🔧 Used tool with result: {result['tool_result']}")
"""
