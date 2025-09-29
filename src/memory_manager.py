import json
import os
from datetime import datetime
from typing import List, Dict


class MemoryManager:
    def __init__(self, memory_file: str = "data/memory/conversations.json"):
        self.memory_file = memory_file
        os.makedirs(os.path.dirname(memory_file), exist_ok=True)

    def save_conversation(self, messages: List[Dict]):
        """Save conversation to JSON memory"""
        try:
            conversation = {
                "timestamp": datetime.now().isoformat(),
                "messages": messages
            }

            # Load existing conversations
            if os.path.exists(self.memory_file):
                with open(self.memory_file, 'r') as f:
                    data = json.load(f)
            else:
                data = {"conversations": []}

            # Add new conversation
            data["conversations"].append(conversation)

            # Keep only last 50 conversations
            if len(data["conversations"]) > 50:
                data["conversations"] = data["conversations"][-50:]

            # Save to file
            with open(self.memory_file, 'w') as f:
                json.dump(data, f, indent=2)

        except Exception as e:
            print(f"Error saving conversation: {e}")

    def load_conversations(self) -> List[Dict]:
        """Load all conversations from memory"""
        try:
            if os.path.exists(self.memory_file):
                with open(self.memory_file, 'r') as f:
                    data = json.load(f)
                return data.get("conversations", [])
            return []
        except Exception as e:
            print(f"Error loading conversations: {e}")
            return []

    def load_last_conversation(self) -> List[Dict]:
        """Load most recent conversation messages or empty list"""
        conversations = self.load_conversations()
        if not conversations:
            return []
        return conversations[-1].get("messages", [])