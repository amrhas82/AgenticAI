from typing import Dict, List, Generator, Optional

# OpenAI v1 SDK
from openai import OpenAI


class OpenAIClient:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key

    def _get_client(self, api_key_override: Optional[str] = None) -> OpenAI:
        key_to_use = api_key_override or self.api_key
        return OpenAI(api_key=key_to_use) if key_to_use else OpenAI()

    def stream_chat_completion(
        self,
        model: str,
        messages: List[Dict[str, str]],
        api_key_override: Optional[str] = None,
    ) -> Generator[str, None, None]:
        """
        Stream a chat completion token-by-token. Yields text chunks.
        Expects messages in [{"role": "user"|"assistant", "content": str}, ...] format.
        """
        client = self._get_client(api_key_override)

        # Ensure roles/content are in correct shape
        normalized: List[Dict[str, str]] = []
        for message in messages:
            role = message.get("role", "user")
            content = message.get("content", "")
            normalized.append({"role": role, "content": content})

        with client.chat.completions.create(
            model=model,
            messages=normalized,
            stream=True,
        ) as stream:
            for chunk in stream:
                delta = chunk.choices[0].delta
                if delta and getattr(delta, "content", None):
                    yield delta.content or ""

    def chat_completion(
        self,
        model: str,
        messages: List[Dict[str, str]],
        api_key_override: Optional[str] = None,
    ) -> str:
        """
        Non-streaming chat completion. Returns the full text.
        """
        client = self._get_client(api_key_override)

        normalized: List[Dict[str, str]] = []
        for message in messages:
            role = message.get("role", "user")
            content = message.get("content", "")
            normalized.append({"role": role, "content": content})

        response = client.chat.completions.create(
            model=model,
            messages=normalized,
        )
        return response.choices[0].message.content or ""
