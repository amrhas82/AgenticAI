import streamlit as st
import json
import os
from datetime import datetime
from dotenv import load_dotenv

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
            st.session_state.messages = []
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"
        if 'initialized' not in st.session_state:
            st.session_state.initialized = True

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
            uploaded_file = st.file_uploader("Upload PDF", type="pdf")
            if uploaded_file is not None:
                if st.button("Process PDF"):
                    try:
                        with st.spinner("Processing PDF..."):
                            text_chunks = self.pdf_processor.process_pdf(uploaded_file)
                            if text_chunks:
                                self.vector_db.store_document(text_chunks, uploaded_file.name)
                                st.success(f"Processed {len(text_chunks)} chunks from {uploaded_file.name}")
                            else:
                                st.warning("No text could be extracted from the PDF.")
                    except Exception as e:
                        st.error(f"Error processing PDF: {str(e)}")

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

            # Get AI response with error handling
            with st.chat_message("assistant"):
                try:
                    with st.spinner("Thinking..."):
                        response = self.ollama.generate_response(
                            prompt,
                            st.session_state.messages[:-1],
                            st.session_state.current_model
                        )
                        st.markdown(response)

                    # Add assistant response to messages
                    st.session_state.messages.append({"role": "assistant", "content": response})

                    # Save to memory with error handling
                    try:
                        self.memory.save_conversation(st.session_state.messages)
                    except Exception as e:
                        st.error(f"Error saving to memory: {e}")

                except Exception as e:
                    error_msg = f"Sorry, I encountered an error: {str(e)}"
                    st.markdown(error_msg)
                    st.session_state.messages.append({"role": "assistant", "content": error_msg})

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