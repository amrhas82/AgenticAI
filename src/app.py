import streamlit as st
import json
import os
from datetime import datetime
from dotenv import load_dotenv

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
            st.session_state.messages = []
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"

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
            uploaded_file = st.file_uploader("Upload PDF", type="pdf")
            if uploaded_file is not None:
                if st.button("Process PDF"):
                    with st.spinner("Processing PDF..."):
                        text_chunks = self.pdf_processor.process_pdf(uploaded_file)
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

            # Get AI response
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    response = self.ollama.generate_response(
                        prompt,
                        st.session_state.messages[:-1],  # Previous messages for context
                        st.session_state.current_model
                    )
                    st.markdown(response)

            # Add assistant response to messages
            st.session_state.messages.append({"role": "assistant", "content": response})

            # Save to memory
            self.memory.save_conversation(st.session_state.messages)

    def run(self):
        """Main application runner"""
        self.setup_sidebar()
        self.display_chat()


if __name__ == "__main__":
    app = AIPlaygroundApp()
    app.run()