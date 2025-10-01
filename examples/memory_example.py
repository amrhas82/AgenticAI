#!/usr/bin/env python3
"""
Memory management example
Demonstrates saving and loading conversation history
Run with: python examples/memory_example.py
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from ui.conversation_manager import EnhancedMemoryManager
from ollama_client import OllamaClient


def main():
    print("=" * 60)
    print("Memory Management Example")
    print("=" * 60)
    
    # Initialize components
    memory = EnhancedMemoryManager("data/memory/example_conversations.json")
    ollama = OllamaClient()
    
    # Get available models
    models = ollama.get_available_models()
    if not models:
        print("\n❌ No Ollama models found. Please pull a model first:")
        print("   ollama pull llama2")
        return
    
    model = models[0]
    print(f"\n✅ Using model: {model}")
    
    # Create a simple conversation
    messages = []
    
    print("\n" + "=" * 60)
    print("Starting a new conversation...")
    print("Type 'save' to save the conversation")
    print("Type 'load' to load previous conversations")
    print("Type 'search <query>' to search conversations")
    print("Type 'quit' to exit")
    print("=" * 60 + "\n")
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() == 'quit':
                break
            
            if user_input.lower() == 'save':
                if messages:
                    title = input("Enter conversation title (optional): ").strip()
                    tags_input = input("Enter tags (comma-separated, optional): ").strip()
                    tags = [t.strip() for t in tags_input.split(",")] if tags_input else []
                    
                    conv_id = memory.save_conversation(
                        messages,
                        title=title if title else None,
                        tags=tags if tags else None
                    )
                    print(f"✅ Conversation saved with ID: {conv_id}\n")
                else:
                    print("⚠️  No messages to save\n")
                continue
            
            if user_input.lower() == 'load':
                conversations = memory.load_conversations(limit=5)
                if conversations:
                    print("\n📚 Recent conversations:")
                    for i, conv in enumerate(conversations, 1):
                        title = conv.get('title', 'Untitled')
                        timestamp = conv.get('timestamp', '')[:19]
                        msg_count = conv.get('message_count', 0)
                        print(f"{i}. {title} - {msg_count} messages ({timestamp})")
                    
                    choice = input("\nEnter number to load (or press Enter to cancel): ").strip()
                    if choice.isdigit():
                        idx = int(choice) - 1
                        if 0 <= idx < len(conversations):
                            messages = conversations[idx]['messages']
                            print(f"✅ Loaded conversation: {conversations[idx].get('title', 'Untitled')}\n")
                            
                            # Display loaded conversation
                            for msg in messages:
                                role = msg['role'].title()
                                content = msg['content'][:100]
                                print(f"{role}: {content}...")
                            print()
                else:
                    print("No conversations found\n")
                continue
            
            if user_input.lower().startswith('search '):
                query = user_input[7:].strip()
                if query:
                    results = memory.search_conversations(query)
                    if results:
                        print(f"\n🔍 Found {len(results)} conversations matching '{query}':")
                        for i, conv in enumerate(results[:5], 1):
                            title = conv.get('title', 'Untitled')
                            timestamp = conv.get('timestamp', '')[:19]
                            print(f"{i}. {title} ({timestamp})")
                        print()
                    else:
                        print(f"No conversations found matching '{query}'\n")
                continue
            
            # Add user message
            messages.append({"role": "user", "content": user_input})
            
            # Generate response
            print("AI: ", end="", flush=True)
            response = ollama.generate_response(user_input, messages[:-1], model)
            print(response + "\n")
            
            # Add AI response
            messages.append({"role": "assistant", "content": response})
            
        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}\n")
    
    # Offer to save on exit
    if messages and len(messages) > 0:
        save = input("\nSave this conversation before exiting? (y/n): ").strip().lower()
        if save == 'y':
            title = input("Enter title (optional): ").strip()
            conv_id = memory.save_conversation(
                messages,
                title=title if title else "Conversation from example"
            )
            print(f"✅ Conversation saved with ID: {conv_id}")
    
    print("\nGoodbye!")


if __name__ == "__main__":
    main()
