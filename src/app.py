import streamlit as st
import json
import os
from datetime import datetime
from dotenv import load_dotenv
from typing import Optional

from ollama_client import OllamaClient
from memory_manager import MemoryManager
from pdf_processor import PDFProcessor
from vector_db import VectorDB
from mcp_client import MCPClient
from utils.config import Config

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
        self.config = Config()
        self.ollama = OllamaClient()
        self.memory = MemoryManager()
        self.pdf_processor = PDFProcessor()
        self.vector_db = VectorDB()
        self.mcp_client = MCPClient()

        # Initialize session state
        if 'messages' not in st.session_state:
            # Attempt to restore last conversation
            last = self.memory.load_last_conversation()
            st.session_state.messages = last if last else []
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"
        if 'current_agent' not in st.session_state:
            st.session_state.current_agent = "General Chat"
        if 'use_rag' not in st.session_state:
            st.session_state.use_rag = False

    def setup_sidebar(self):
        """Setup sidebar with controls"""
        with st.sidebar:
            st.title("🤖 AI Playground Controls")

            # Model selection
            st.subheader("Model Settings")
            available_models = self.ollama.get_available_models()
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

            # PDF Processing
            st.subheader("Document Processing")
            uploaded_file = st.file_uploader("Upload Document (pdf, txt, md)", type=["pdf", "txt", "md"]) 
            if uploaded_file is not None:
                if st.button("Process PDF"):
                    with st.spinner("Processing PDF..."):
                        if uploaded_file.type == "application/pdf" or uploaded_file.name.lower().endswith(".pdf"):
                            text_chunks = self.pdf_processor.process_pdf(uploaded_file)
                        else:
                            raw_text = uploaded_file.read().decode("utf-8", errors="ignore")
                            text_chunks = self.pdf_processor._split_text(raw_text)
                        self.vector_db.store_document(text_chunks, uploaded_file.name)
                        st.success(f"Processed {len(text_chunks)} chunks from {uploaded_file.name}")

            # System info
            st.subheader("System Info")
            st.write(f"Current Model: {st.session_state.current_model}")
            st.write(f"Messages: {len(st.session_state.messages)}")

            # MCP Status
            st.subheader("MCP Status")
            mcp_status = self.mcp_client.get_status()
            st.write(f"Klavis MCP: {mcp_status}")

    def display_chat(self):
        """Display chat interface"""
        st.title("💬 AI Agent Playground")
        st.markdown("Chat with local AI models and explore agent capabilities!")

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

            # Prepare system prompt
            system_prompt = self._get_system_prompt()

            # Retrieve RAG context if enabled
            rag_context = None
            if st.session_state.use_rag or st.session_state.current_agent == "RAG Assistant":
                top_chunks = self.vector_db.search_similar(prompt, limit=5)
                if top_chunks:
                    rag_context = "\n\n".join(top_chunks)

            # Get AI response
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    augmented_prompt = self._build_augmented_prompt(prompt, system_prompt, rag_context)
                    response = self.ollama.generate_response(
                        augmented_prompt,
                        st.session_state.messages[:-1],  # Previous messages for context
                        st.session_state.current_model
                    )
                    st.markdown(response)

            # Add assistant response to messages
            st.session_state.messages.append({"role": "assistant", "content": response})

            # Save to memory
            self.memory.save_conversation(st.session_state.messages)

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
        self.setup_sidebar()
        self.display_chat()


if __name__ == "__main__":
    app = AIPlaygroundApp()
    app.run()