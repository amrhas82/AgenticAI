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
from openai_client import OpenAIClient
from typing import Optional

# Load environment variables
load_dotenv()

# Validate local modules availability (already imported above)
try:
    _ = (OllamaClient, MemoryManager, PDFProcessor, VectorDB, MCPClient, Config)
except Exception as e:
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
        self.config = Config()
        self.ollama = OllamaClient()
        self.openai_client = OpenAIClient(api_key=self.config.openai_api_key)
        self.memory = MemoryManager()
        self.pdf_processor = PDFProcessor()
        self.vector_db = VectorDB()
        self.mcp_client = MCPClient()
        self.init_session_state()

    def init_session_state(self):
        """Initialize session state with defaults"""
        if 'messages' not in st.session_state:
            st.session_state.messages = []
        if 'provider' not in st.session_state:
            st.session_state.provider = "Local (Ollama)"
        if 'current_model' not in st.session_state:
            st.session_state.current_model = "llama2"
        if 'openai_model' not in st.session_state:
            st.session_state.openai_model = "gpt-3.5-turbo"
        if 'openai_api_key' not in st.session_state:
            st.session_state.openai_api_key = self.config.openai_api_key or ""
        if 'current_agent' not in st.session_state:
            st.session_state.current_agent = "General Chat"
        if 'use_rag' not in st.session_state:
            st.session_state.use_rag = False

    def setup_sidebar(self):
        """Setup sidebar with controls and error handling"""
        with st.sidebar:
            st.title("🤖 AI Playground Controls")

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
                    index=available_models.index(st.session_state.current_model) if st.session_state.current_model in available_models else 0
                )
                if selected_model != st.session_state.current_model:
                    st.session_state.current_model = selected_model
                    st.rerun()
            else:
                openai_models = [
                    "gpt-4o-mini",
                    "gpt-4o",
                    "gpt-3.5-turbo"
                ]
                selected_openai_model = st.selectbox(
                    "Choose OpenAI Model:",
                    openai_models,
                    index=openai_models.index(st.session_state.openai_model) if st.session_state.openai_model in openai_models else 0
                )
                if selected_openai_model != st.session_state.openai_model:
                    st.session_state.openai_model = selected_openai_model
                    st.rerun()

                # API Key input (not persisted to disk)
                st.caption("Enter your OpenAI API key (kept in session only)")
                api_key_input = st.text_input("OPENAI_API_KEY", value=st.session_state.openai_api_key, type="password")
                if api_key_input != st.session_state.openai_api_key:
                    st.session_state.openai_api_key = api_key_input

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
                if st.button("Process Document"):
                    try:
                        name = getattr(uploaded_file, 'name', 'uploaded')
                        if name.lower().endswith('.pdf'):
                            chunks = self.pdf_processor.process_pdf(uploaded_file)
                        else:
                            content = uploaded_file.read().decode('utf-8', errors='ignore')
                            chunks = self._split_text(content)
                        if chunks:
                            self.vector_db.store_document(chunks, name)
                            st.success(f"Processed and stored {len(chunks)} chunks from '{name}'.")
                        else:
                            st.warning("No content extracted from the document.")
                    except Exception as e:
                        st.error(f"Document processing error: {e}")

            # Export conversation
            st.subheader("Export")
            if st.session_state.messages:
                export_data = json.dumps({"messages": st.session_state.messages}, indent=2).encode("utf-8")
                st.download_button(
                    label="Download Conversation JSON",
                    data=export_data,
                    file_name="conversation.json",
                    mime="application/json"
                )

            # System info
            st.subheader("System Info")
            st.write(f"Provider: {st.session_state.provider}")
            if st.session_state.provider == "Local (Ollama)":
                st.write(f"Current Model: {st.session_state.current_model}")
            else:
                st.write(f"OpenAI Model: {st.session_state.openai_model}")
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

            # Build system prompt and optional RAG context
            system_prompt = self._get_system_prompt()
            rag_context = None
            if st.session_state.use_rag:
                try:
                    hits = self.vector_db.search_similar(prompt)
                    rag_context = "\n\n".join(hits) if hits else None
                except Exception as e:
                    st.warning(f"RAG retrieval error: {e}")

            augmented = self._build_augmented_prompt(prompt, system_prompt, rag_context)

            # Generate response and display
            with st.chat_message("assistant"):
                if st.session_state.provider == "Local (Ollama)":
                    try:
                        with st.spinner("Thinking..."):
                            response = self.ollama.generate_response(
                                augmented,
                                st.session_state.messages[:-1],
                                st.session_state.current_model
                            )
                    except Exception as e:
                        response = f"There was an error generating a response: {e}"
                    st.markdown(response)
                else:
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

            # Persist conversation
            try:
                self.memory.save_conversation(st.session_state.messages)
            except Exception:
                pass

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

    def _split_text(self, text: str):
        """Split plain text into overlapping chunks (mirrors PDFProcessor)."""
        words = text.split()
        chunks = []
        chunk_size = 1000
        chunk_overlap = 200
        for i in range(0, len(words), chunk_size - chunk_overlap):
            chunk = " ".join(words[i:i + chunk_size])
            if chunk:
                chunks.append(chunk)
            if i + chunk_size >= len(words):
                break
        return chunks

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
