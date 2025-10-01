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
