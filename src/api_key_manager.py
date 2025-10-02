import os
import hashlib
import secrets
from typing import Optional, Dict, List
from datetime import datetime, timedelta
import json

# Try psycopg2 first (Python < 3.13), then psycopg (3.13+)
try:
    import psycopg2
    _HAVE_PSYCOPG = True
    _PSYCOPG_VERSION = 2
except Exception:
    try:
        import psycopg as psycopg2  # Use psycopg3 with psycopg2 compatible API
        _HAVE_PSYCOPG = True
        _PSYCOPG_VERSION = 3
    except Exception:
        psycopg2 = None
        _HAVE_PSYCOPG = False
        _PSYCOPG_VERSION = 0


class APIKeyManager:
    """Manages API keys for external agent authentication"""
    
    def __init__(self):
        self.connection_string = os.getenv("DATABASE_URL")
        self.master_key = os.getenv("MASTER_API_KEY")
        self.enable_auth = os.getenv("ENABLE_API_AUTH", "false").lower() == "true"
        self._use_postgres = bool(self.connection_string) and _HAVE_PSYCOPG
        self._json_path = os.getenv("API_KEYS_JSON_PATH", "data/memory/api_keys.json")
        
        if not self._use_postgres:
            os.makedirs(os.path.dirname(self._json_path), exist_ok=True)
    
    def generate_api_key(self) -> str:
        """Generate a secure random API key"""
        return f"sk_{secrets.token_urlsafe(32)}"
    
    def hash_key(self, api_key: str) -> str:
        """Create a secure hash of the API key"""
        return hashlib.sha256(api_key.encode()).hexdigest()
    
    def create_key(
        self,
        name: str,
        description: str = "",
        permissions: Optional[Dict] = None,
        expires_days: Optional[int] = None
    ) -> Optional[str]:
        """
        Create a new API key
        
        Args:
            name: Friendly name for the key
            description: Description of the key's purpose
            permissions: Dictionary of permissions
            expires_days: Days until expiration (None for no expiration)
        
        Returns:
            The generated API key (shown only once)
        """
        try:
            api_key = self.generate_api_key()
            key_hash = self.hash_key(api_key)
            
            if permissions is None:
                permissions = {
                    "chat": True,
                    "documents": True,
                    "memory": True
                }
            
            expires_at = None
            if expires_days:
                expires_at = datetime.now() + timedelta(days=expires_days)
            
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute(
                    """
                    INSERT INTO api_keys (key_hash, name, description, permissions, expires_at)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (
                        key_hash,
                        name,
                        description,
                        json.dumps(permissions),
                        expires_at
                    )
                )
                
                conn.commit()
                cursor.close()
                conn.close()
            else:
                # JSON fallback
                keys = self._json_load()
                keys.append({
                    "key_hash": key_hash,
                    "name": name,
                    "description": description,
                    "permissions": permissions,
                    "is_active": True,
                    "created_at": datetime.now().isoformat(),
                    "last_used_at": None,
                    "expires_at": expires_at.isoformat() if expires_at else None
                })
                self._json_save(keys)
            
            return api_key
            
        except Exception as e:
            print(f"Error creating API key: {e}")
            return None
    
    def verify_key(self, api_key: str) -> Dict[str, any]:
        """
        Verify an API key and return its permissions
        
        Returns:
            Dict with 'valid' boolean and 'permissions' if valid
        """
        if not self.enable_auth:
            # Authentication disabled - allow all
            return {
                "valid": True,
                "permissions": {"chat": True, "documents": True, "memory": True},
                "name": "No Auth"
            }
        
        # Check master key first
        if self.master_key and api_key == self.master_key:
            return {
                "valid": True,
                "permissions": {"chat": True, "documents": True, "memory": True, "admin": True},
                "name": "Master Key"
            }
        
        try:
            key_hash = self.hash_key(api_key)
            
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute(
                    """
                    SELECT name, permissions, expires_at, is_active
                    FROM api_keys
                    WHERE key_hash = %s
                    """,
                    (key_hash,)
                )
                
                row = cursor.fetchone()
                
                if row:
                    name, permissions_json, expires_at, is_active = row
                    
                    # Check if active
                    if not is_active:
                        cursor.close()
                        conn.close()
                        return {"valid": False, "reason": "Key is deactivated"}
                    
                    # Check expiration
                    if expires_at and datetime.now() > expires_at:
                        cursor.close()
                        conn.close()
                        return {"valid": False, "reason": "Key has expired"}
                    
                    # Update last used timestamp
                    cursor.execute(
                        "UPDATE api_keys SET last_used_at = %s WHERE key_hash = %s",
                        (datetime.now(), key_hash)
                    )
                    conn.commit()
                    
                    cursor.close()
                    conn.close()
                    
                    return {
                        "valid": True,
                        "permissions": json.loads(permissions_json) if isinstance(permissions_json, str) else permissions_json,
                        "name": name
                    }
                
                cursor.close()
                conn.close()
                
            else:
                # JSON fallback
                keys = self._json_load()
                
                for key_data in keys:
                    if key_data.get("key_hash") == key_hash:
                        # Check if active
                        if not key_data.get("is_active", True):
                            return {"valid": False, "reason": "Key is deactivated"}
                        
                        # Check expiration
                        expires_at = key_data.get("expires_at")
                        if expires_at:
                            expires_dt = datetime.fromisoformat(expires_at)
                            if datetime.now() > expires_dt:
                                return {"valid": False, "reason": "Key has expired"}
                        
                        # Update last used
                        key_data["last_used_at"] = datetime.now().isoformat()
                        self._json_save(keys)
                        
                        return {
                            "valid": True,
                            "permissions": key_data.get("permissions", {}),
                            "name": key_data.get("name", "Unknown")
                        }
            
            return {"valid": False, "reason": "Invalid API key"}
            
        except Exception as e:
            print(f"Error verifying API key: {e}")
            return {"valid": False, "reason": f"Verification error: {e}"}
    
    def list_keys(self) -> List[Dict]:
        """List all API keys (without revealing the actual keys)"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute(
                    """
                    SELECT name, description, is_active, created_at, last_used_at, expires_at
                    FROM api_keys
                    ORDER BY created_at DESC
                    """
                )
                
                results = [
                    {
                        "name": row[0],
                        "description": row[1],
                        "is_active": row[2],
                        "created_at": row[3].isoformat() if row[3] else None,
                        "last_used_at": row[4].isoformat() if row[4] else None,
                        "expires_at": row[5].isoformat() if row[5] else None
                    }
                    for row in cursor.fetchall()
                ]
                
                cursor.close()
                conn.close()
                return results
            else:
                keys = self._json_load()
                return [
                    {
                        "name": k.get("name"),
                        "description": k.get("description"),
                        "is_active": k.get("is_active"),
                        "created_at": k.get("created_at"),
                        "last_used_at": k.get("last_used_at"),
                        "expires_at": k.get("expires_at")
                    }
                    for k in keys
                ]
        except Exception as e:
            print(f"Error listing keys: {e}")
            return []
    
    def revoke_key(self, name: str) -> bool:
        """Revoke an API key by name"""
        try:
            if self._use_postgres:
                conn = psycopg2.connect(self.connection_string)
                cursor = conn.cursor()
                
                cursor.execute(
                    "UPDATE api_keys SET is_active = false WHERE name = %s",
                    (name,)
                )
                
                conn.commit()
                cursor.close()
                conn.close()
                return True
            else:
                keys = self._json_load()
                for key_data in keys:
                    if key_data.get("name") == name:
                        key_data["is_active"] = False
                self._json_save(keys)
                return True
        except Exception as e:
            print(f"Error revoking key: {e}")
            return False
    
    def _json_load(self) -> List[dict]:
        """Load API keys from JSON file"""
        try:
            if os.path.exists(self._json_path):
                with open(self._json_path, "r") as f:
                    return json.load(f)
            return []
        except Exception:
            return []
    
    def _json_save(self, keys: List[dict]) -> None:
        """Save API keys to JSON file"""
        try:
            with open(self._json_path, "w") as f:
                json.dump(keys, f, indent=2)
        except Exception as e:
            print(f"Error saving API keys: {e}")


def require_api_key(permission: str = None):
    """
    Decorator to require API key authentication
    
    Usage:
        @require_api_key("documents")
        def upload_document():
            ...
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            import streamlit as st
            
            # Get API key from query params or session state
            api_key = st.query_params.get("api_key") or st.session_state.get("api_key")
            
            if not api_key:
                st.error("API key required. Please provide an API key.")
                st.stop()
            
            # Verify key
            key_manager = APIKeyManager()
            verification = key_manager.verify_key(api_key)
            
            if not verification.get("valid"):
                st.error(f"Invalid API key: {verification.get('reason', 'Unknown error')}")
                st.stop()
            
            # Check permission if specified
            if permission:
                permissions = verification.get("permissions", {})
                if not permissions.get(permission, False):
                    st.error(f"API key does not have '{permission}' permission")
                    st.stop()
            
            # Store verification in session
            st.session_state["api_verification"] = verification
            
            return func(*args, **kwargs)
        
        return wrapper
    return decorator
