"""
Data Manager - SQLite database manager for SynthChat Android app.

Handles all local data storage including users, characters, and messages.
"""

import sqlite3
import hashlib
import os
from datetime import datetime
from typing import Optional, Dict, List, Tuple, Any


class DataManager:
    """Manages SQLite database for SynthChat."""
    
    def __init__(self, db_path: str):
        """Initialize the data manager.
        
        Args:
            db_path: Path to the SQLite database file
        """
        self.db_path = db_path
        self._init_database()
    
    def _get_connection(self) -> sqlite3.Connection:
        """Get a database connection."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def _init_database(self):
        """Initialize database tables."""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Users table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                last_login TEXT
            )
        ''')
        
        # Characters table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS characters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                avatar_path TEXT DEFAULT 'default.png',
                description TEXT DEFAULT '',
                personality TEXT DEFAULT '',
                system_prompt TEXT DEFAULT '',
                greeting TEXT DEFAULT 'Hello! How can I help you?',
                model TEXT DEFAULT 'gpt-3.5-turbo',
                temperature REAL DEFAULT 0.7,
                max_tokens INTEGER DEFAULT 500,
                traits TEXT DEFAULT '{}',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            )
        ''')
        
        # Messages table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                character_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                thought_pattern TEXT DEFAULT '',
                emotion TEXT DEFAULT 'neutral',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def _hash_password(self, password: str) -> str:
        """Hash a password using SHA-256."""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def _row_to_dict(self, row: sqlite3.Row) -> Dict[str, Any]:
        """Convert a database row to a dictionary."""
        if row is None:
            return None
        return dict(row)
    
    # User methods
    
    def create_user(self, username: str, email: str, password: str) -> Tuple[bool, Any]:
        """Create a new user.
        
        Args:
            username: Username
            email: Email address
            password: Plain text password
            
        Returns:
            Tuple of (success, user_dict or error_message)
        """
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            password_hash = self._hash_password(password)
            
            cursor.execute('''
                INSERT INTO users (username, email, password_hash)
                VALUES (?, ?, ?)
            ''', (username, email.lower(), password_hash))
            
            user_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            return True, self.get_user_by_id(user_id)
        except sqlite3.IntegrityError as e:
            if 'username' in str(e):
                return False, "Username already taken"
            elif 'email' in str(e):
                return False, "Email already registered"
            return False, str(e)
        except Exception as e:
            return False, str(e)
    
    def authenticate_user(self, username: str, password: str) -> Optional[Dict]:
        """Authenticate a user.
        
        Args:
            username: Username or email
            password: Plain text password
            
        Returns:
            User dict if authenticated, None otherwise
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        password_hash = self._hash_password(password)
        
        cursor.execute('''
            SELECT * FROM users 
            WHERE (username = ? OR email = ?) AND password_hash = ?
        ''', (username, username.lower(), password_hash))
        
        row = cursor.fetchone()
        
        if row:
            # Update last login
            cursor.execute('''
                UPDATE users SET last_login = ? WHERE id = ?
            ''', (datetime.now().isoformat(), row['id']))
            conn.commit()
        
        conn.close()
        return self._row_to_dict(row)
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict]:
        """Get a user by ID."""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM users WHERE id = ?', (user_id,))
        row = cursor.fetchone()
        
        conn.close()
        return self._row_to_dict(row)
    
    # Character methods
    
    def create_character(self, user_id: int, name: str, personality: str = '',
                        system_prompt: str = '', greeting: str = '',
                        avatar_path: str = None, **kwargs) -> Tuple[bool, Any]:
        """Create a new character.
        
        Args:
            user_id: Owner user ID
            name: Character name
            personality: Personality description
            system_prompt: System prompt for LLM
            greeting: Initial greeting message
            avatar_path: Path to avatar image
            
        Returns:
            Tuple of (success, character_dict or error_message)
        """
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            if not system_prompt:
                system_prompt = f"You are {name}. {personality}"
            if not greeting:
                greeting = f"Hello! I'm {name}. How can I help you today?"
            
            cursor.execute('''
                INSERT INTO characters (user_id, name, personality, system_prompt, 
                                        greeting, avatar_path, description, model,
                                        temperature, max_tokens)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                user_id, name, personality, system_prompt, greeting,
                avatar_path or 'default.png',
                kwargs.get('description', ''),
                kwargs.get('model', 'gpt-3.5-turbo'),
                kwargs.get('temperature', 0.7),
                kwargs.get('max_tokens', 500)
            ))
            
            char_id = cursor.lastrowid
            conn.commit()
            conn.close()
            
            return True, self.get_character(char_id)
        except Exception as e:
            return False, str(e)
    
    def get_character(self, character_id: int) -> Optional[Dict]:
        """Get a character by ID."""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM characters WHERE id = ?', (character_id,))
        row = cursor.fetchone()
        
        conn.close()
        return self._row_to_dict(row)
    
    def get_characters(self, user_id: int) -> List[Dict]:
        """Get all characters for a user."""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT c.*, 
                   (SELECT COUNT(*) FROM messages WHERE character_id = c.id) as message_count
            FROM characters c
            WHERE user_id = ?
            ORDER BY updated_at DESC
        ''', (user_id,))
        
        rows = cursor.fetchall()
        conn.close()
        
        return [self._row_to_dict(row) for row in rows]
    
    def update_character(self, character_id: int, **kwargs) -> bool:
        """Update a character.
        
        Args:
            character_id: Character ID
            **kwargs: Fields to update
            
        Returns:
            True if successful
        """
        if not kwargs:
            return True
        
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            # Build update query
            fields = []
            values = []
            for key, value in kwargs.items():
                if key in ['name', 'personality', 'system_prompt', 'greeting',
                          'avatar_path', 'description', 'model', 'temperature',
                          'max_tokens', 'traits']:
                    fields.append(f"{key} = ?")
                    values.append(value)
            
            if not fields:
                return True
            
            fields.append("updated_at = ?")
            values.append(datetime.now().isoformat())
            values.append(character_id)
            
            cursor.execute(f'''
                UPDATE characters SET {', '.join(fields)} WHERE id = ?
            ''', values)
            
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            print(f"Error updating character: {e}")
            return False
    
    def delete_character(self, character_id: int) -> bool:
        """Delete a character and all its messages."""
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            cursor.execute('DELETE FROM messages WHERE character_id = ?', (character_id,))
            cursor.execute('DELETE FROM characters WHERE id = ?', (character_id,))
            
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            print(f"Error deleting character: {e}")
            return False
    
    # Message methods
    
    def add_message(self, character_id: int, role: str, content: str,
                   thought_pattern: str = '', emotion: str = 'neutral') -> Dict:
        """Add a message to a character's conversation.
        
        Args:
            character_id: Character ID
            role: 'user' or 'assistant'
            content: Message content
            thought_pattern: Internal thought pattern
            emotion: Emotional state
            
        Returns:
            Message dict
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO messages (character_id, role, content, thought_pattern, emotion)
            VALUES (?, ?, ?, ?, ?)
        ''', (character_id, role, content, thought_pattern, emotion))
        
        msg_id = cursor.lastrowid
        
        # Update character's updated_at
        cursor.execute('''
            UPDATE characters SET updated_at = ? WHERE id = ?
        ''', (datetime.now().isoformat(), character_id))
        
        conn.commit()
        
        cursor.execute('SELECT * FROM messages WHERE id = ?', (msg_id,))
        row = cursor.fetchone()
        
        conn.close()
        return self._row_to_dict(row)
    
    def get_messages(self, character_id: int, limit: int = 50) -> List[Dict]:
        """Get messages for a character.
        
        Args:
            character_id: Character ID
            limit: Maximum number of messages
            
        Returns:
            List of message dicts
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT * FROM messages 
            WHERE character_id = ?
            ORDER BY created_at ASC
            LIMIT ?
        ''', (character_id, limit))
        
        rows = cursor.fetchall()
        conn.close()
        
        return [self._row_to_dict(row) for row in rows]
    
    def clear_messages(self, character_id: int) -> bool:
        """Clear all messages for a character."""
        try:
            conn = self._get_connection()
            cursor = conn.cursor()
            
            cursor.execute('DELETE FROM messages WHERE character_id = ?', (character_id,))
            
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            print(f"Error clearing messages: {e}")
            return False
