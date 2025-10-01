import streamlit as st
import os
from dotenv import load_dotenv

from ollama_client import OllamaClient
from pdf_processor import PDFProcessor
from mcp_client import MCPClient
from openai_client import OpenAIClient
from typing import Optional

# Import new enhanced modules
from database.enhanced_vector_db import EnhancedVectorDB
from ui.document_manager import DocumentManager
from ui.conversation_manager import EnhancedMemoryManager, ConversationManagerUI
from utils.config_manager import ConfigManager, ConfigUI
from agents.agent_system import AgentRegistry

# Load environment variables
load_dotenv()

# Page configuration
st.set_page_config(
    page_title="AI Agent Playground",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)


class AIPlaygroundApp:
    def __init__(self):
        # Configuration
        self.config_manager = ConfigManager()
        self.config_ui = ConfigUI(self.config_manager)
        
        # Core components
        self.ollama = OllamaClient()
        # Initialize OpenAI client with environment key (overridden via UI when provided)
        self.openai_client = OpenAIClient(api_key=os.getenv("OPENAI_API_KEY"))
        self.pdf_processor = PDFProcessor()
        self.mcp_client = MCPClient()
        
        # Enhanced components
        self.vector_db = EnhancedVectorDB()
        self.memory = EnhancedMemoryManager()
        self.doc_manager = DocumentManager(self.vector_db, self.pdf_processor)
        self.conversation_ui = ConversationManagerUI(self.memory)
        
        # Agent system
        self.agent_registry = AgentRegistry()
        self._setup_agents()
        
        self.init_session_state()

    def _setup_agents(self):
        """Setup agent registry with tools"""
        # Create default agents with tools
        self.agent_registry.create_default_agents(self.vector_db, self.memory)
        
        # You can add custom agents here
        # custom_agent = Agent(...)
        # self.agent_registry.register(custom_agent)

    def init_session_state(self):
        """Initialize session state with defaults"""
        if 'messages' not in st.session_state:
            st.session_state.messages = []
        if 'provider' not in st.session_state:
            st.session_state.provider = "Local (Ollama)"
        if 'theme' not in st.session_state:
            st.session_state.theme = self.config_manager.system_config.theme
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"
        if 'openai_model' not in st.session_state:
            st.session_state.openai_model = "gpt-3.5-turbo"
        if 'openai_api_key' not in st.session_state:
            st.session_state.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        if 'current_agent' not in st.session_state:
            st.session_state.current_agent = "General Chat"
        if 'use_rag' not in st.session_state:
            st.session_state.use_rag = False
        if 'mcp_url' not in st.session_state:
            st.session_state.mcp_url = self.config_manager.system_config.mcp_url
        if 'page' not in st.session_state:
            st.session_state.page = "Chat"
        if 'current_conversation_id' not in st.session_state:
            st.session_state.current_conversation_id = None

    def setup_sidebar(self):
        """Setup sidebar with controls"""
        with st.sidebar:
            st.title("🤖 AI Playground")
            
            # Navigation
            st.subheader("Navigation")
            page = st.radio(
                "Go to:",
                ["💬 Chat", "📚 Documents", "🗂️ Conversations", "⚙️ Settings"],
                key="navigation"
            )
            
            # Update page state
            if "💬" in page:
                st.session_state.page = "Chat"
            elif "📚" in page:
                st.session_state.page = "Documents"
            elif "🗂️" in page:
                st.session_state.page = "Conversations"
            elif "⚙️" in page:
                st.session_state.page = "Settings"
            
            st.divider()
            
            # Provider selection
            st.subheader("Provider")
            provider = st.radio(
                "Choose Provider:",
                ["Local (Ollama)", "OpenAI"],
                index=0 if st.session_state.provider == "Local (Ollama)" else 1,
            )
            if provider != st.session_state.provider:
                st.session_state.provider = provider
                st.rerun()

            # Model selection
            st.subheader("Model Settings")
            if st.session_state.provider == "Local (Ollama)":
                available_models = self.ollama.get_available_models()
                selected_model = st.selectbox(
                    "Choose Local Model:",
                    available_models,
                    index=available_models.index(st.session_state.current_model) 
                        if st.session_state.current_model in available_models else 0
                )
                if selected_model != st.session_state.current_model:
                    st.session_state.current_model = selected_model
                    st.rerun()
            else:
                openai_models = ["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]
                selected_openai_model = st.selectbox(
                    "Choose OpenAI Model:",
                    openai_models,
                    index=openai_models.index(st.session_state.openai_model) 
                        if st.session_state.openai_model in openai_models else 0
                )
                if selected_openai_model != st.session_state.openai_model:
                    st.session_state.openai_model = selected_openai_model
                    st.rerun()

                # API Key input
                st.caption("Enter your OpenAI API key")
                api_key_input = st.text_input(
                    "OPENAI_API_KEY", 
                    value=st.session_state.openai_api_key, 
                    type="password"
                )
                if api_key_input != st.session_state.openai_api_key:
                    st.session_state.openai_api_key = api_key_input

            # Agent selection
            st.subheader("Agent Settings")
            agents = self.agent_registry.list_agents()
            selected_agent = st.selectbox(
                "Choose Agent:", 
                agents,
                index=agents.index(st.session_state.current_agent) 
                    if st.session_state.current_agent in agents else 0
            )
            use_rag = st.toggle("Enable RAG context", value=st.session_state.use_rag)
            
            if selected_agent != st.session_state.current_agent or use_rag != st.session_state.use_rag:
                st.session_state.current_agent = selected_agent
                st.session_state.use_rag = use_rag
                st.rerun()

            # Theme toggle
            st.subheader("UI Settings")
            theme = st.selectbox(
                "Theme", 
                ["Light", "Dark"], 
                index=0 if st.session_state.theme == "Light" else 1
            )
            if theme != st.session_state.theme:
                st.session_state.theme = theme
                self.config_manager.system_config.theme = theme
                self.config_manager.save_config()
                st.rerun()

            st.divider()
            
            # Quick actions based on current page
            if st.session_state.page == "Chat":
                st.subheader("Chat Actions")
                if st.button("🗑️ Clear Chat"):
                    st.session_state.messages = []
                    st.session_state.current_conversation_id = None
                    st.rerun()
                
                if st.session_state.messages and st.button("💾 Save Conversation"):
                    conv_id = self.memory.save_conversation(
                        st.session_state.messages,
                        title=st.session_state.messages[0]['content'][:50] 
                            if st.session_state.messages else "Untitled"
                    )
                    st.session_state.current_conversation_id = conv_id
                    st.success("Conversation saved!")
                
                # Recent conversations quick access
                st.divider()
                self.conversation_ui.render_sidebar_quick_access()
            
            elif st.session_state.page == "Documents":
                # Document management in sidebar
                self.doc_manager.render_document_sidebar()
            
            # System info
            st.divider()
            st.subheader("System Info")
            st.write(f"Provider: {st.session_state.provider}")
            if st.session_state.provider == "Local (Ollama)":
                st.write(f"Model: {st.session_state.current_model}")
            else:
                st.write(f"Model: {st.session_state.openai_model}")
            st.write(f"Agent: {st.session_state.current_agent}")
            st.write(f"Messages: {len(st.session_state.messages)}")
            
            # Vector DB stats
            stats = self.vector_db.get_document_stats()
            st.write(f"Documents: {stats.get('total_documents', 0)}")
            st.write(f"Chunks: {stats.get('total_chunks', 0)}")

    def display_chat(self):
        """Display chat interface"""
        st.title("💬 AI Agent Playground")
        st.markdown("Chat with AI agents and explore capabilities!")

        # Apply theme
        if st.session_state.theme == "Dark":
            st.markdown(
                """
                <style>
                .stApp { background-color: #0e1117; color: #e8eaed; }
                </style>
                """,
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                """
                <style>
                .stApp { background-color: #ffffff; color: #111827; }
                </style>
                """,
                unsafe_allow_html=True,
            )

        # Display current agent info
        current_agent = self.agent_registry.get(st.session_state.current_agent)
        if current_agent:
            with st.expander("ℹ️ Current Agent Info", expanded=False):
                st.write(f"**Agent:** {current_agent.config.name}")
                st.write(f"**System Prompt:** {current_agent.config.system_prompt[:200]}...")
                if current_agent.tools:
                    st.write(f"**Available Tools:** {', '.join(current_agent.tools.keys())}")

        # Display chat messages
        for message in st.session_state.messages:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])

        # Chat input
        if prompt := st.chat_input("What would you like to explore?"):
            # Add user message
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)

            # Get agent and generate response
            agent = self.agent_registry.get(st.session_state.current_agent)
            
            with st.chat_message("assistant"):
                if st.session_state.provider == "Local (Ollama)":
                    try:
                        with st.spinner("Thinking..."):
                            if agent:
                                # Use agent system
                                result = agent.process_message(prompt, self.ollama)
                                response = result["response"]
                                
                                # Show tool usage if applicable
                                if result["tool_used"]:
                                    with st.expander("🔧 Tool Used"):
                                        st.json(result["tool_result"])
                            else:
                                # Fallback to basic generation
                                response = self.ollama.generate_response(
                                    prompt,
                                    st.session_state.messages[:-1],
                                    st.session_state.current_model
                                )
                    except Exception as e:
                        response = f"Error: {e}"
                    
                    st.markdown(response)
                else:
                    # OpenAI streaming
                    if not st.session_state.openai_api_key:
                        st.warning("Please provide an OPENAI_API_KEY in the sidebar.")
                        response = ""
                    else:
                        message_placeholder = st.empty()
                        full_response = ""
                        for chunk in self.openai_client.stream_chat_completion(
                            model=st.session_state.openai_model,
                            messages=st.session_state.messages,
                            api_key_override=st.session_state.openai_api_key,
                        ):
                            full_response += chunk
                            message_placeholder.markdown(full_response + "|")
                        message_placeholder.markdown(full_response)
                        response = full_response

            # Add assistant message
            st.session_state.messages.append({"role": "assistant", "content": response})

            # Auto-save if enabled
            if self.config_manager.system_config.auto_save_conversations:
                try:
                    self.memory.save_conversation(st.session_state.messages)
                except Exception:
                    pass

    def run(self):
        """Main application runner"""
        try:
            self.setup_sidebar()
            
            # Route to appropriate page
            if st.session_state.page == "Chat":
                self.display_chat()
            elif st.session_state.page == "Documents":
                self.doc_manager.render_document_explorer()
            elif st.session_state.page == "Conversations":
                self.conversation_ui.render_conversation_history()
            elif st.session_state.page == "Settings":
                self.config_ui.render_settings_page()
                
        except Exception as e:
            st.error(f"Application error: {str(e)}")
            st.info("Please check that all services are running properly.")


if __name__ == "__main__":
    app = AIPlaygroundApp()
    app.run()
