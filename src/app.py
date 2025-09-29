import streamlit as st
import json
import os
from datetime import datetime
from dotenv import load_dotenv
from typing import Optional

# Load environment variables
load_dotenv()

# Import local modules
try:
    from ollama_client import OllamaClient
    from memory_manager import MemoryManager
    from pdf_processor import PDFProcessor
    from vector_db import VectorDB
    from mcp_client import MCPClient
    from utils.config import Config
except ImportError as e:
    st.error(f"Module import error: {e}. Please check your installation.")
    st.stop()

# Page configuration
st.set_page_config(
    page_title="AI Agent Playground",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)


class AIPlaygroundApp:
    def __init__(self):
        self.init_session_state()
        try:
            self.config = Config()
            self.ollama = OllamaClient()
            self.memory = MemoryManager()
            self.pdf_processor = PDFProcessor()
            self.vector_db = VectorDB()
            self.mcp_client = MCPClient()
        except Exception as e:
            st.error(f"Initialization error: {e}")
            st.stop()

    def init_session_state(self):
        """Initialize session state with defaults"""
        if 'messages' not in st.session_state:
            # Attempt to restore last conversation
            last = self.memory.load_last_conversation()
            st.session_state.messages = last if last else []
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"

    def setup_sidebar(self):
        """Setup sidebar with controls and error handling"""
        with st.sidebar:
            st.title("🤖 AI Playground Controls")

            # Model selection with error handling
            st.subheader("Model Settings")
            try:
                available_models = self.ollama.get_available_models()
                if not available_models:
                    available_models = ["llama2", "mistral"]  # Fallback
                    st.warning("No models detected. Using defaults.")
            except Exception as e:
                st.error(f"Error loading models: {e}")
                available_models = ["llama2", "mistral"]  # Fallback

            selected_model = st.selectbox(
                "Choose AI Model:",
                available_models,
                index=available_models.index(
                    st.session_state.current_model) if st.session_state.current_model in available_models else 0
            )

            if selected_model != st.session_state.current_model:
                st.session_state.current_model = selected_model
                st.rerun()

            # Agent selection
            st.subheader("Agent Settings")
            agents = ["General Chat", "RAG Assistant", "Coder (DeepSeek style)"]
            selected_agent = st.selectbox("Choose Agent:", agents, index=agents.index(st.session_state.current_agent) if st.session_state.current_agent in agents else 0)
            use_rag = st.toggle("Enable RAG context", value=st.session_state.use_rag)
            if selected_agent != st.session_state.current_agent or use_rag != st.session_state.use_rag:
                st.session_state.current_agent = selected_agent
                st.session_state.use_rag = use_rag
                st.rerun()

            # Theme selection
            st.subheader("UI Settings")
            theme = st.selectbox("Theme", ["Light", "Dark"], index=1)

            # Memory management
            st.subheader("Memory")
            if st.button("Clear Conversation History"):
                st.session_state.messages = []
                st.rerun()

            # PDF Processing with error handling
            st.subheader("Document Processing")
            uploaded_file = st.file_uploader("Upload Document (pdf, txt, md)", type=["pdf", "txt", "md"]) 
            if uploaded_file is not None:
                if st.button("Process PDF"):

            # System info
            st.subheader("System Info")
            st.write(f"Current Model: {st.session_state.current_model}")
            st.write(f"Messages: {len(st.session_state.messages)}")

            # MCP Status with error handling
            st.subheader("MCP Status")
            try:
                mcp_status = self.mcp_client.get_status()
                st.write(f"Klavis MCP: {mcp_status}")
            except Exception as e:
                st.error(f"MCP Status error: {str(e)}")

    def display_chat(self):
        """Display chat interface with error handling"""
        st.title("💬 AI Agent Playground")
        st.markdown("Chat with local AI models and explore agent capabilities!")

        # Display chat messages
        for message in st.session_state.messages:
            with st.chat_message(message["role"]):
                st.markdown(message["content"])

        # Chat input with error handling
        if prompt := st.chat_input("What would you like to explore?"):
            # Add user message
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)

    def _get_system_prompt(self) -> str:
        agent = st.session_state.current_agent
        if agent == "Coder (DeepSeek style)":
            return (
                "You are a meticulous coding assistant inspired by DeepSeek's reasoning. "
                "Plan before coding, propose structured steps, write clear, runnable code, "
                "and verify outputs mentally. Prefer local tools and minimal dependencies."
            )
        if agent == "RAG Assistant":
            return (
                "You augment answers with retrieved document context. Cite which chunks you used. "
                "If context is insufficient, say so and ask for more docs."
            )
        return "You are a helpful local AI assistant."

    def _build_augmented_prompt(self, user_prompt: str, system_prompt: str, rag_context: Optional[str]) -> str:
        parts = [f"[System]\n{system_prompt}"]
        if rag_context:
            parts.append(f"[Context]\n{rag_context}")
        parts.append(f"[User]\n{user_prompt}")
        return "\n\n".join(parts)

    def run(self):
        """Main application runner"""
        try:
            self.setup_sidebar()
            self.display_chat()
        except Exception as e:
            st.error(f"Application error: {str(e)}")
            st.info("Please check that all services are running properly.")


if __name__ == "__main__":
    app = AIPlaygroundApp()
    app.run()