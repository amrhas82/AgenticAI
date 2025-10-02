import json
import os
from datetime import datetime
from typing import List, Dict, Optional
import streamlit as st


class EnhancedMemoryManager:
    """Enhanced conversation memory with tagging, search, and branching"""
    
    def __init__(self, memory_file: str = "data/memory/conversations.json"):
        self.memory_file = memory_file
        os.makedirs(os.path.dirname(memory_file), exist_ok=True)
    
    def save_conversation(
        self,
        messages: List[Dict],
        title: Optional[str] = None,
        tags: Optional[List[str]] = None,
        metadata: Optional[Dict] = None
    ):
        """Save conversation with enhanced metadata"""
        try:
            # Generate title from first user message if not provided
            if not title and messages:
                first_msg = next((m for m in messages if m['role'] == 'user'), None)
                if first_msg:
                    title = first_msg['content'][:50] + "..." if len(first_msg['content']) > 50 else first_msg['content']
            
            conversation = {
                "id": self._generate_id(),
                "timestamp": datetime.now().isoformat(),
                "title": title or "Untitled Conversation",
                "tags": tags or [],
                "messages": messages,
                "metadata": metadata or {},
                "message_count": len(messages)
            }
            
            # Load existing conversations
            data = self._load_data()
            
            # Add new conversation
            data["conversations"].append(conversation)
            
            # Keep only last 100 conversations
            if len(data["conversations"]) > 100:
                data["conversations"] = data["conversations"][-100:]
            
            # Save to file
            self._save_data(data)
            
            return conversation["id"]
            
        except Exception as e:
            print(f"Error saving conversation: {e}")
            return None
    
    def load_conversations(
        self,
        tags: Optional[List[str]] = None,
        limit: Optional[int] = None
    ) -> List[Dict]:
        """Load conversations with optional filtering"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            # Filter by tags
            if tags:
                conversations = [
                    conv for conv in conversations
                    if any(tag in conv.get("tags", []) for tag in tags)
                ]
            
            # Sort by timestamp (newest first)
            conversations.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
            
            # Apply limit
            if limit:
                conversations = conversations[:limit]
            
            return conversations
            
        except Exception as e:
            print(f"Error loading conversations: {e}")
            return []
    
    def search_conversations(self, query: str) -> List[Dict]:
        """Search conversations by content"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            results = []
            query_lower = query.lower()
            
            for conv in conversations:
                # Search in title
                if query_lower in conv.get("title", "").lower():
                    results.append(conv)
                    continue
                
                # Search in messages
                for msg in conv.get("messages", []):
                    if query_lower in msg.get("content", "").lower():
                        results.append(conv)
                        break
                
                # Search in tags
                if any(query_lower in tag.lower() for tag in conv.get("tags", [])):
                    results.append(conv)
            
            # Sort by timestamp
            results.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
            
            return results
            
        except Exception as e:
            print(f"Error searching conversations: {e}")
            return []
    
    def get_conversation(self, conversation_id: str) -> Optional[Dict]:
        """Get specific conversation by ID"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            for conv in conversations:
                if conv.get("id") == conversation_id:
                    return conv
            
            return None
            
        except Exception as e:
            print(f"Error getting conversation: {e}")
            return None
    
    def delete_conversation(self, conversation_id: str) -> bool:
        """Delete a conversation"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            # Filter out the conversation
            data["conversations"] = [
                conv for conv in conversations
                if conv.get("id") != conversation_id
            ]
            
            self._save_data(data)
            return True
            
        except Exception as e:
            print(f"Error deleting conversation: {e}")
            return False
    
    def update_conversation_tags(
        self,
        conversation_id: str,
        tags: List[str]
    ) -> bool:
        """Update tags for a conversation"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            for conv in conversations:
                if conv.get("id") == conversation_id:
                    conv["tags"] = tags
                    break
            
            self._save_data(data)
            return True
            
        except Exception as e:
            print(f"Error updating tags: {e}")
            return False
    
    def get_all_tags(self) -> List[str]:
        """Get all unique tags across conversations"""
        try:
            data = self._load_data()
            conversations = data.get("conversations", [])
            
            tags = set()
            for conv in conversations:
                tags.update(conv.get("tags", []))
            
            return sorted(list(tags))
            
        except Exception as e:
            print(f"Error getting tags: {e}")
            return []
    
    def export_conversation(self, conversation_id: str, format: str = "json") -> Optional[str]:
        """Export conversation in various formats"""
        conversation = self.get_conversation(conversation_id)
        if not conversation:
            return None
        
        if format == "json":
            return json.dumps(conversation, indent=2)
        
        elif format == "markdown":
            md = f"# {conversation.get('title', 'Conversation')}\n\n"
            md += f"Date: {conversation.get('timestamp', 'Unknown')[:19]}\n\n"
            
            if conversation.get('tags'):
                md += f"Tags: {', '.join(conversation['tags'])}\n\n"
            
            md += "---\n\n"
            
            for msg in conversation.get("messages", []):
                role = msg.get("role", "unknown").title()
                content = msg.get("content", "")
                md += f"## {role}\n\n{content}\n\n"
            
            return md
        
        elif format == "txt":
            txt = f"{conversation.get('title', 'Conversation')}\n"
            txt += f"{'=' * 50}\n\n"
            
            for msg in conversation.get("messages", []):
                role = msg.get("role", "unknown").upper()
                content = msg.get("content", "")
                txt += f"[{role}]\n{content}\n\n"
            
            return txt
        
        return None
    
    def _generate_id(self) -> str:
        """Generate unique conversation ID"""
        import hashlib
        timestamp = datetime.now().isoformat()
        return hashlib.md5(timestamp.encode()).hexdigest()[:12]
    
    def _load_data(self) -> Dict:
        """Load data from JSON file"""
        if os.path.exists(self.memory_file):
            with open(self.memory_file, 'r') as f:
                return json.load(f)
        return {"conversations": []}
    
    def _save_data(self, data: Dict):
        """Save data to JSON file"""
        with open(self.memory_file, 'w') as f:
            json.dump(data, f, indent=2)


class ConversationManagerUI:
    """UI component for managing conversations in Streamlit"""
    
    def __init__(self, memory_manager: EnhancedMemoryManager):
        self.memory = memory_manager
    
    def render_conversation_history(self):
        """Render conversation history browser"""
        st.title("💬 Conversation History")
        
        # Search and filter
        col1, col2 = st.columns([3, 1])
        
        with col1:
            search_query = st.text_input(
                "Search conversations",
                placeholder="Enter keywords...",
                key="conv_search"
            )
        
        with col2:
            if st.button("🔍 Search", type="primary"):
                st.session_state['search_active'] = True
        
        # Tag filter
        all_tags = self.memory.get_all_tags()
        if all_tags:
            selected_tags = st.multiselect(
                "Filter by tags",
                all_tags,
                key="tag_filter"
            )
        else:
            selected_tags = []
        
        st.divider()
        
        # Load conversations
        if search_query and st.session_state.get('search_active'):
            conversations = self.memory.search_conversations(search_query)
            st.info(f"Found {len(conversations)} matching conversations")
        elif selected_tags:
            conversations = self.memory.load_conversations(tags=selected_tags)
        else:
            conversations = self.memory.load_conversations(limit=20)
        
        # Display conversations
        if conversations:
            for conv in conversations:
                self._render_conversation_card(conv)
        else:
            st.info("No conversations found. Start chatting to create history!")
    
    def _render_conversation_card(self, conversation: Dict):
        """Render a single conversation card"""
        # Generate a unique key for this conversation
        conv_id = conversation.get('id')
        if not conv_id:
            # If no ID, generate one from timestamp or use a hash
            import hashlib
            conv_id = hashlib.md5(str(conversation.get('timestamp', '')).encode()).hexdigest()[:12]
        
        with st.expander(
            f"💬 {conversation.get('title', 'Untitled')} - {conversation.get('timestamp', '')[:19]}",
            expanded=False
        ):
            # Metadata
            col1, col2, col3 = st.columns(3)
            
            with col1:
                message_count = conversation.get('message_count', len(conversation.get('messages', [])))
                st.text(f"Messages: {message_count}")
            
            with col2:
                tags = conversation.get('tags', [])
                if tags:
                    st.text(f"Tags: {', '.join(tags)}")
            
            with col3:
                st.text(f"ID: {conv_id[:8]}")
            
            # Message preview
            messages = conversation.get('messages', [])
            if messages:
                st.markdown("**Preview:**")
                preview_msg = messages[0] if messages[0].get('role') == 'user' else (messages[1] if len(messages) > 1 else messages[0])
                preview_text = preview_msg.get('content', '')[:200]
                st.text(preview_text + "..." if len(preview_msg.get('content', '')) > 200 else preview_text)
            
            st.divider()
            
            # Actions
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                if st.button("📖 Load", key=f"load_{conv_id}"):
                    st.session_state.messages = conversation.get('messages', [])
                    st.session_state['loaded_conversation_id'] = conv_id
                    st.success("Conversation loaded!")
                    st.rerun()
            
            with col2:
                if st.button("🏷️ Tags", key=f"tags_{conv_id}"):
                    st.session_state['edit_tags_for'] = conv_id
            
            with col3:
                export_format = st.selectbox(
                    "Format",
                    ["json", "markdown", "txt"],
                    key=f"export_format_{conv_id}",
                    label_visibility="collapsed"
                )
                
                exported = self.memory.export_conversation(
                    conv_id,
                    export_format
                )
                
                if exported:
                    filename = f"conversation_{conv_id}.{export_format}"
                    st.download_button(
                        "💾 Export",
                        data=exported,
                        file_name=filename,
                        key=f"export_{conv_id}"
                    )
            
            with col4:
                if st.button("🗑️ Delete", key=f"delete_{conv_id}"):
                    if self.memory.delete_conversation(conv_id):
                        st.success("Deleted!")
                        st.rerun()
            
            # Tag editor
            if st.session_state.get('edit_tags_for') == conv_id:
                st.divider()
                current_tags = conversation.get('tags', [])
                new_tags_input = st.text_input(
                    "Enter tags (comma-separated)",
                    value=", ".join(current_tags),
                    key=f"new_tags_{conv_id}"
                )
                
                if st.button("Save Tags", key=f"save_tags_{conv_id}"):
                    new_tags = [tag.strip() for tag in new_tags_input.split(",") if tag.strip()]
                    if self.memory.update_conversation_tags(conv_id, new_tags):
                        st.success("Tags updated!")
                        del st.session_state['edit_tags_for']
                        st.rerun()
    
    def render_sidebar_quick_access(self):
        """Render quick access to recent conversations in sidebar"""
        st.subheader("📚 Recent Conversations")
        
        recent = self.memory.load_conversations(limit=5)
        
        if recent:
            for idx, conv in enumerate(recent):
                title = conv.get('title', 'Untitled')[:30]
                # Use 'id' if available, otherwise use index as fallback
                conv_key = conv.get('id', f"conv_{idx}")
                if st.button(f"💬 {title}", key=f"quick_{conv_key}"):
                    st.session_state.messages = conv.get('messages', [])
                    st.success(f"Loaded: {title}")
                    st.rerun()
        else:
            st.info("No recent conversations")
        
        st.divider()
        
        if st.button("📖 View All Conversations"):
            st.session_state['page'] = 'conversations'
            st.rerun()


# Usage in app.py:
"""
# In AIPlaygroundApp.__init__():
self.memory = EnhancedMemoryManager()
self.conversation_ui = ConversationManagerUI(self.memory)

# In setup_sidebar():
self.conversation_ui.render_sidebar_quick_access()

# Add new page:
page = st.sidebar.radio("Navigation", ["Chat", "Documents", "Conversations"])

if page == "Conversations":
    self.conversation_ui.render_conversation_history()
"""
