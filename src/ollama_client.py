import os
import ollama
from typing import List, Dict

class OllamaClient:
    def __init__(self):
        # Instantiate a reusable Ollama client
        self.host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        self.client = ollama.Client(host=self.host)

    def get_available_models(self) -> List[str]:
        """Get list of available Ollama models with error handling"""
        try:
            models = self.client.list()
            return [model['name'] for model in models['models']]
        except Exception as e:
            # Avoid UI dependencies here; return reasonable defaults
            return ["llama2", "mistral"]

    def generate_response(self, prompt: str, history: List[Dict], model: str) -> str:
        """Generate response from Ollama model with error handling"""
        try:
            # Prepare messages for context (last 6 messages)
            messages = []
            for msg in history[-6:]:
                messages.append({"role": msg["role"], "content": msg["content"]})
            messages.append({"role": "user", "content": prompt})

            response = self.client.chat(model=model, messages=messages)
            return response['message']['content']
        except Exception as e:
            # Enrich common connection error with actionable hint
            err_msg = str(e)
            if "Connection refused" in err_msg or "Failed to establish a new connection" in err_msg:
                raise Exception(
                    f"Ollama API error: {err_msg}. Check that Ollama is reachable at {self.host} and that your container/env OLLAMA_HOST points to it."
                )
            raise Exception(f"Ollama API error: {err_msg}")