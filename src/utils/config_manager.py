import os
import json
import streamlit as st
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict


@dataclass
class ModelConfig:
    """Configuration for a specific model"""
    name: str
    temperature: float = 0.7
    max_tokens: int = 2000
    top_p: float = 0.9
    frequency_penalty: float = 0.0
    presence_penalty: float = 0.0


@dataclass
class RAGConfig:
    """Configuration for RAG system"""
    chunk_size: int = 1000
    chunk_overlap: int = 200
    similarity_threshold: float = 0.7
    max_results: int = 5
    enable_reranking: bool = True


@dataclass
class SystemConfig:
    """Overall system configuration"""
    ollama_host: str = "http://localhost:11434"
    embed_model: str = "nomic-embed-text"
    embed_dim: int = 768
    database_url: str = "postgresql://ai_user:ai_password@localhost:5432/ai_playground"
    mcp_url: str = "http://localhost:8080"
    theme: str = "Dark"
    auto_save_conversations: bool = True
    max_conversation_history: int = 10


class ConfigManager:
    """Manages application configuration with persistence"""
    
    def __init__(self, config_file: str = "data/config/settings.json"):
        self.config_file = config_file
        os.makedirs(os.path.dirname(config_file), exist_ok=True)
        
        self.system_config = self._load_system_config()
        self.model_configs: Dict[str, ModelConfig] = self._load_model_configs()
        self.rag_config = self._load_rag_config()
    
    def _load_system_config(self) -> SystemConfig:
        """Load system configuration"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    data = json.load(f)
                    system_data = data.get('system', {})
                    return SystemConfig(**system_data)
        except Exception as e:
            print(f"Error loading system config: {e}")
        
        # Return defaults, overridden by environment variables
        return SystemConfig(
            ollama_host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
            embed_model=os.getenv("EMBED_MODEL", "nomic-embed-text"),
            embed_dim=int(os.getenv("EMBED_DIM", "768")),
            database_url=os.getenv("DATABASE_URL", "postgresql://ai_user:ai_password@localhost:5432/ai_playground"),
            mcp_url=os.getenv("MCP_URL", "http://localhost:8080")
        )
    
    def _load_model_configs(self) -> Dict[str, ModelConfig]:
        """Load model configurations"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    data = json.load(f)
                    models_data = data.get('models', {})
                    return {
                        name: ModelConfig(**config)
                        for name, config in models_data.items()
                    }
        except Exception as e:
            print(f"Error loading model configs: {e}")
        
        # Return defaults
        return {
            "llama2": ModelConfig(name="llama2", temperature=0.7),
            "mistral": ModelConfig(name="mistral", temperature=0.7),
            "codellama": ModelConfig(name="codellama", temperature=0.3),
        }
    
    def _load_rag_config(self) -> RAGConfig:
        """Load RAG configuration"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    data = json.load(f)
                    rag_data = data.get('rag', {})
                    return RAGConfig(**rag_data)
        except Exception as e:
            print(f"Error loading RAG config: {e}")
        
        return RAGConfig()
    
    def save_config(self):
        """Save all configurations to file"""
        try:
            data = {
                'system': asdict(self.system_config),
                'models': {
                    name: asdict(config)
                    for name, config in self.model_configs.items()
                },
                'rag': asdict(self.rag_config)
            }
            
            with open(self.config_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False
    
    def get_model_config(self, model_name: str) -> ModelConfig:
        """Get configuration for a specific model"""
        if model_name in self.model_configs:
            return self.model_configs[model_name]
        
        # Return default config for unknown models
        return ModelConfig(name=model_name)
    
    def update_model_config(self, model_name: str, config: ModelConfig):
        """Update configuration for a specific model"""
        self.model_configs[model_name] = config
        self.save_config()
    
    def reset_to_defaults(self):
        """Reset all configurations to defaults"""
        self.system_config = SystemConfig()
        self.model_configs = {
            "llama2": ModelConfig(name="llama2", temperature=0.7),
            "mistral": ModelConfig(name="mistral", temperature=0.7),
            "codellama": ModelConfig(name="codellama", temperature=0.3),
        }
        self.rag_config = RAGConfig()
        self.save_config()


class ConfigUI:
    """UI component for configuration management"""
    
    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
    
    def render_settings_page(self):
        """Render full settings page"""
        st.title("⚙️ Settings")
        
        tabs = st.tabs(["🔧 System", "🤖 Models", "📚 RAG", "💾 Import/Export"])
        
        with tabs[0]:
            self._render_system_settings()
        
        with tabs[1]:
            self._render_model_settings()
        
        with tabs[2]:
            self._render_rag_settings()
        
        with tabs[3]:
            self._render_import_export()
    
    def _render_system_settings(self):
        """Render system settings"""
        st.subheader("System Configuration")
        
        # Ollama settings
        st.markdown("### Ollama Settings")
        ollama_host = st.text_input(
            "Ollama Host",
            value=self.config.system_config.ollama_host,
            key="setting_ollama_host"
        )
        
        col1, col2 = st.columns(2)
        with col1:
            embed_model = st.text_input(
                "Embedding Model",
                value=self.config.system_config.embed_model,
                key="setting_embed_model"
            )
        
        with col2:
            embed_dim = st.number_input(
                "Embedding Dimension",
                value=self.config.system_config.embed_dim,
                min_value=128,
                max_value=2048,
                step=64,
                key="setting_embed_dim"
            )
        
        st.divider()
        
        # Database settings
        st.markdown("### Database Settings")
        database_url = st.text_input(
            "Database URL",
            value=self.config.system_config.database_url,
            type="password",
            key="setting_database_url"
        )
        
        st.divider()
        
        # MCP settings
        st.markdown("### MCP Settings")
        mcp_url = st.text_input(
            "MCP URL",
            value=self.config.system_config.mcp_url,
            key="setting_mcp_url"
        )
        
        st.divider()
        
        # UI settings
        st.markdown("### UI Settings")
        auto_save = st.checkbox(
            "Auto-save conversations",
            value=self.config.system_config.auto_save_conversations,
            key="setting_auto_save"
        )
        
        max_history = st.number_input(
            "Max conversation history",
            value=self.config.system_config.max_conversation_history,
            min_value=1,
            max_value=50,
            step=1,
            key="setting_max_history"
        )
        
        st.divider()
        
        # Save button
        if st.button("💾 Save System Settings", type="primary"):
            self.config.system_config.ollama_host = ollama_host
            self.config.system_config.embed_model = embed_model
            self.config.system_config.embed_dim = embed_dim
            self.config.system_config.database_url = database_url
            self.config.system_config.mcp_url = mcp_url
            self.config.system_config.auto_save_conversations = auto_save
            self.config.system_config.max_conversation_history = max_history
            
            if self.config.save_config():
                st.success("✅ Settings saved successfully!")
            else:
                st.error("❌ Failed to save settings")
    
    def _render_model_settings(self):
        """Render model-specific settings"""
        st.subheader("Model Configuration")
        
        st.info("Configure parameters for specific models. These will be used when the model is selected.")
        
        # Model selector
        available_models = list(self.config.model_configs.keys())
        selected_model = st.selectbox(
            "Select Model to Configure",
            available_models,
            key="model_config_select"
        )
        
        if selected_model:
            config = self.config.model_configs[selected_model]
            
            st.markdown(f"### {selected_model}")
            
            col1, col2 = st.columns(2)
            
            with col1:
                temperature = st.slider(
                    "Temperature",
                    min_value=0.0,
                    max_value=2.0,
                    value=config.temperature,
                    step=0.1,
                    key=f"temp_{selected_model}"
                )
                
                top_p = st.slider(
                    "Top P",
                    min_value=0.0,
                    max_value=1.0,
                    value=config.top_p,
                    step=0.05,
                    key=f"top_p_{selected_model}"
                )
            
            with col2:
                max_tokens = st.number_input(
                    "Max Tokens",
                    min_value=100,
                    max_value=8000,
                    value=config.max_tokens,
                    step=100,
                    key=f"max_tokens_{selected_model}"
                )
                
                frequency_penalty = st.slider(
                    "Frequency Penalty",
                    min_value=0.0,
                    max_value=2.0,
                    value=config.frequency_penalty,
                    step=0.1,
                    key=f"freq_penalty_{selected_model}"
                )
            
            presence_penalty = st.slider(
                "Presence Penalty",
                min_value=0.0,
                max_value=2.0,
                value=config.presence_penalty,
                step=0.1,
                key=f"pres_penalty_{selected_model}"
            )
            
            st.divider()
            
            # Save button
            col1, col2 = st.columns([1, 1])
            with col1:
                if st.button("💾 Save Model Settings", type="primary", key=f"save_{selected_model}"):
                    updated_config = ModelConfig(
                        name=selected_model,
                        temperature=temperature,
                        max_tokens=max_tokens,
                        top_p=top_p,
                        frequency_penalty=frequency_penalty,
                        presence_penalty=presence_penalty
                    )
                    self.config.update_model_config(selected_model, updated_config)
                    st.success(f"✅ Settings saved for {selected_model}")
            
            with col2:
                if st.button("🔄 Reset to Defaults", key=f"reset_{selected_model}"):
                    default_config = ModelConfig(name=selected_model)
                    self.config.update_model_config(selected_model, default_config)
                    st.success(f"✅ Reset {selected_model} to defaults")
                    st.rerun()
    
    def _render_rag_settings(self):
        """Render RAG configuration settings"""
        st.subheader("RAG Configuration")
        
        st.info("Configure how documents are processed and retrieved for RAG (Retrieval Augmented Generation).")
        
        col1, col2 = st.columns(2)
        
        with col1:
            chunk_size = st.number_input(
                "Chunk Size (words)",
                min_value=100,
                max_value=3000,
                value=self.config.rag_config.chunk_size,
                step=100,
                key="rag_chunk_size"
            )
            
            similarity_threshold = st.slider(
                "Similarity Threshold",
                min_value=0.0,
                max_value=1.0,
                value=self.config.rag_config.similarity_threshold,
                step=0.05,
                key="rag_similarity"
            )
        
        with col2:
            chunk_overlap = st.number_input(
                "Chunk Overlap (words)",
                min_value=0,
                max_value=1000,
                value=self.config.rag_config.chunk_overlap,
                step=50,
                key="rag_chunk_overlap"
            )
            
            max_results = st.number_input(
                "Max Results",
                min_value=1,
                max_value=20,
                value=self.config.rag_config.max_results,
                step=1,
                key="rag_max_results"
            )
        
        enable_reranking = st.checkbox(
            "Enable Result Reranking",
            value=self.config.rag_config.enable_reranking,
            key="rag_rerank"
        )
        
        st.divider()
        
        # Save button
        if st.button("💾 Save RAG Settings", type="primary"):
            self.config.rag_config.chunk_size = chunk_size
            self.config.rag_config.chunk_overlap = chunk_overlap
            self.config.rag_config.similarity_threshold = similarity_threshold
            self.config.rag_config.max_results = max_results
            self.config.rag_config.enable_reranking = enable_reranking
            
            if self.config.save_config():
                st.success("✅ RAG settings saved successfully!")
            else:
                st.error("❌ Failed to save settings")
    
    def _render_import_export(self):
        """Render import/export functionality"""
        st.subheader("Import/Export Configuration")
        
        # Export
        st.markdown("### 📤 Export Settings")
        st.write("Download your current configuration as JSON.")
        
        if st.button("Download Configuration", type="primary"):
            config_data = {
                'system': asdict(self.config.system_config),
                'models': {
                    name: asdict(config)
                    for name, config in self.config.model_configs.items()
                },
                'rag': asdict(self.config.rag_config)
            }
            
            config_json = json.dumps(config_data, indent=2)
            st.download_button(
                label="💾 Download config.json",
                data=config_json,
                file_name="ai_playground_config.json",
                mime="application/json"
            )
        
        st.divider()
        
        # Import
        st.markdown("### 📥 Import Settings")
        st.write("Upload a previously exported configuration file.")
        
        uploaded_config = st.file_uploader(
            "Choose configuration file",
            type=['json'],
            key="config_upload"
        )
        
        if uploaded_config is not None:
            try:
                config_data = json.load(uploaded_config)
                
                st.json(config_data)
                
                if st.button("⚠️ Import and Replace Current Settings", type="secondary"):
                    # Load system config
                    if 'system' in config_data:
                        self.config.system_config = SystemConfig(**config_data['system'])
                    
                    # Load model configs
                    if 'models' in config_data:
                        self.config.model_configs = {
                            name: ModelConfig(**config)
                            for name, config in config_data['models'].items()
                        }
                    
                    # Load RAG config
                    if 'rag' in config_data:
                        self.config.rag_config = RAGConfig(**config_data['rag'])
                    
                    # Save
                    if self.config.save_config():
                        st.success("✅ Configuration imported successfully!")
                        st.info("Please refresh the page to apply changes.")
                    else:
                        st.error("❌ Failed to save imported configuration")
                        
            except Exception as e:
                st.error(f"❌ Error loading configuration: {e}")
        
        st.divider()
        
        # Reset to defaults
        st.markdown("### ⚠️ Reset to Defaults")
        st.warning("This will reset ALL settings to their default values.")
        
        if st.button("🔄 Reset All Settings to Defaults", type="secondary"):
            self.config.reset_to_defaults()
            st.success("✅ All settings reset to defaults!")
            st.info("Please refresh the page to see changes.")
