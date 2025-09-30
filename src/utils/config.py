import os


class Config:
    def __init__(self):
        self.database_url = os.getenv("DATABASE_URL", "postgresql://ai_user:ai_password@localhost:5432/ai_playground")
        self.ollama_host = os.getenv("OLLAMA_HOST", "localhost")
        # Optional: OpenAI API key can be supplied via env or UI at runtime
        self.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        self.memory_file = os.getenv("MEMORY_FILE", "data/memory/conversations.json")

    def validate(self):
        """Validate configuration"""
        if not self.database_url:
            raise ValueError("DATABASE_URL environment variable is required")
        return True
