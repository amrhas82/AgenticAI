import ollama
from typing import List, Dict

class OllamaClient:
    def __init__(self):

    def get_available_models(self) -> List[str]:
        """Get list of available Ollama models with error handling"""
        try:
            models = self.client.list()
            return [model['name'] for model in models['models']]
        except Exception as e:
            st.error(f"Error fetching models: {e}")
            return ["llama2", "mistral"]  # Fallback

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