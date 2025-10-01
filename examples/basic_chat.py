#!/usr/bin/env python3
"""
Basic chat example without Streamlit
Run with: python examples/basic_chat.py
"""

from src.ollama_client import OllamaClient


def main():
    client = OllamaClient()
    models = client.get_available_models()

    print("Available models:", models)

    while True:
        user_input = input("\nYou: ")
        if user_input.lower() in ['quit', 'exit', 'q']:
            break

        response = client.generate_response(user_input, [], models[0])
        print(f"AI: {response}")


if __name__ == "__main__":
    main()