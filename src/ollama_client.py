import ollama
from typing import List, Dict

class OllamaClient:
    def __init__(self):
        # Instantiate a reusable Ollama client
        self.client = ollama.Client()

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
            raise Exception(f"Ollama API error: {str(e)}")