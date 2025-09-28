import os

class Config:
    def __init__(self):
        self.database_url = os.getenv("DATABASE_URL", "postgresql://ai_user:ai_password@localhost:5432/ai_playground")
        self.ollama_host = os.getenv("OLLAMA_HOST", "localhost")