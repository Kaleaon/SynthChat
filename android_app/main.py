#!/usr/bin/env python3
"""
SynthChat Android App - Silly Tavern Style LLM Manager

A Kivy-based Android application for managing multiple AI characters
with Google Drive integration for persistent memory.
"""

import os
import sys
import json
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from kivy.app import App
from kivy.core.window import Window
from kivy.uix.screenmanager import ScreenManager, SlideTransition
from kivy.properties import ObjectProperty, StringProperty, ListProperty, BooleanProperty
from kivy.clock import Clock
from kivy.storage.jsonstore import JsonStore

# Set window size for desktop testing (ignored on Android)
Window.size = (400, 700)

# Import screens
from screens.login_screen import LoginScreen
from screens.register_screen import RegisterScreen
from screens.characters_screen import CharactersScreen
from screens.chat_screen import ChatScreen
from screens.character_edit_screen import CharacterEditScreen

# Import utilities
from utils.data_manager import DataManager


class SynthChatApp(App):
    """Main SynthChat Application."""
    
    # App-wide properties
    current_user = ObjectProperty(None, allownone=True)
    current_character = ObjectProperty(None, allownone=True)
    characters = ListProperty([])
    is_logged_in = BooleanProperty(False)
    
    # Theme colors
    primary_color = ListProperty([0.39, 0.4, 0.95, 1])  # Purple
    secondary_color = ListProperty([0.55, 0.36, 0.96, 1])  # Violet
    bg_color = ListProperty([0.1, 0.1, 0.18, 1])  # Dark blue
    bg_secondary = ListProperty([0.09, 0.13, 0.24, 1])  # Darker blue
    text_color = ListProperty([0.95, 0.96, 0.97, 1])  # Light gray
    text_secondary = ListProperty([0.61, 0.64, 0.69, 1])  # Gray
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.data_manager = None
        self.store = None
    
    def build(self):
        """Build the application."""
        self.title = 'SynthChat'
        
        # Initialize data storage
        self._init_storage()
        
        # Create screen manager
        self.sm = ScreenManager(transition=SlideTransition())
        
        # Add screens
        self.sm.add_widget(LoginScreen(name='login'))
        self.sm.add_widget(RegisterScreen(name='register'))
        self.sm.add_widget(CharactersScreen(name='characters'))
        self.sm.add_widget(ChatScreen(name='chat'))
        self.sm.add_widget(CharacterEditScreen(name='character_edit'))
        
        # Check for saved session
        Clock.schedule_once(self._check_session, 0.5)
        
        return self.sm
    
    def _init_storage(self):
        """Initialize local storage."""
        # Get app data directory
        if hasattr(self, 'user_data_dir'):
            data_dir = self.user_data_dir
        else:
            data_dir = os.path.join(os.path.dirname(__file__), 'data')
        
        os.makedirs(data_dir, exist_ok=True)
        
        # Initialize JSON store for settings
        store_path = os.path.join(data_dir, 'synthchat.json')
        self.store = JsonStore(store_path)
        
        # Initialize data manager
        db_path = os.path.join(data_dir, 'synthchat.db')
        self.data_manager = DataManager(db_path)
    
    def _check_session(self, dt):
        """Check for saved login session."""
        if self.store.exists('session'):
            session = self.store.get('session')
            user_id = session.get('user_id')
            if user_id:
                user = self.data_manager.get_user_by_id(user_id)
                if user:
                    self.current_user = user
                    self.is_logged_in = True
                    self.load_characters()
                    self.sm.current = 'characters'
                    return
        
        # No valid session, show login
        self.sm.current = 'login'
    
    def login(self, username, password):
        """Log in a user."""
        user = self.data_manager.authenticate_user(username, password)
        if user:
            self.current_user = user
            self.is_logged_in = True
            
            # Save session
            self.store.put('session', user_id=user['id'])
            
            # Load characters
            self.load_characters()
            
            self.sm.current = 'characters'
            return True, "Login successful"
        return False, "Invalid username or password"
    
    def register(self, username, email, password):
        """Register a new user."""
        success, result = self.data_manager.create_user(username, email, password)
        if success:
            # Auto-login after registration
            return self.login(username, password)
        return False, result
    
    def logout(self):
        """Log out the current user."""
        self.current_user = None
        self.current_character = None
        self.characters = []
        self.is_logged_in = False
        
        # Clear session
        if self.store.exists('session'):
            self.store.delete('session')
        
        self.sm.current = 'login'
    
    def load_characters(self):
        """Load characters for current user."""
        if self.current_user:
            self.characters = self.data_manager.get_characters(self.current_user['id'])
    
    def create_character(self, name, personality, system_prompt, greeting, avatar_path=None):
        """Create a new character."""
        if not self.current_user:
            return False, "Not logged in"
        
        success, result = self.data_manager.create_character(
            user_id=self.current_user['id'],
            name=name,
            personality=personality,
            system_prompt=system_prompt,
            greeting=greeting,
            avatar_path=avatar_path
        )
        
        if success:
            self.load_characters()
        
        return success, result
    
    def update_character(self, character_id, **kwargs):
        """Update a character."""
        success = self.data_manager.update_character(character_id, **kwargs)
        if success:
            self.load_characters()
            # Update current character if it's the one being edited
            if self.current_character and self.current_character['id'] == character_id:
                self.current_character = self.data_manager.get_character(character_id)
        return success
    
    def delete_character(self, character_id):
        """Delete a character."""
        success = self.data_manager.delete_character(character_id)
        if success:
            self.load_characters()
            if self.current_character and self.current_character['id'] == character_id:
                self.current_character = None
        return success
    
    def select_character(self, character_id):
        """Select a character for chatting."""
        character = self.data_manager.get_character(character_id)
        if character:
            self.current_character = character
            self.sm.current = 'chat'
    
    def send_message(self, content):
        """Send a message to the current character."""
        if not self.current_character:
            return None
        
        # Save user message
        user_msg = self.data_manager.add_message(
            character_id=self.current_character['id'],
            role='user',
            content=content
        )
        
        # Generate AI response
        response = self._generate_response(content)
        
        # Save assistant message
        assistant_msg = self.data_manager.add_message(
            character_id=self.current_character['id'],
            role='assistant',
            content=response['content'],
            thought_pattern=response.get('thought_pattern', ''),
            emotion=response.get('emotion', 'neutral')
        )
        
        return {
            'user_message': user_msg,
            'assistant_message': assistant_msg
        }
    
    def _generate_response(self, user_input):
        """Generate AI response using LLM or fallback."""
        character = self.current_character
        
        # Get recent conversation history
        messages = self.data_manager.get_messages(character['id'], limit=10)
        
        # Generate thought pattern
        thought_parts = []
        if '?' in user_input:
            thought_parts.append("User is asking a question")
        if len(messages) > 0:
            thought_parts.append(f"Building on {len(messages)} previous messages")
        thought_pattern = " | ".join(thought_parts) if thought_parts else "Processing input"
        
        # Determine emotion
        user_lower = user_input.lower()
        if any(w in user_lower for w in ['happy', 'great', 'thanks', 'awesome']):
            emotion = 'happy'
        elif any(w in user_lower for w in ['sad', 'sorry', 'bad']):
            emotion = 'empathetic'
        elif '?' in user_input:
            emotion = 'curious'
        else:
            emotion = 'neutral'
        
        # Try to use OpenAI if available
        try:
            import openai
            api_key = os.getenv('OPENAI_API_KEY')
            if api_key:
                client = openai.OpenAI(api_key=api_key)
                
                # Build messages
                api_messages = [
                    {"role": "system", "content": character.get('system_prompt') or 
                     f"You are {character['name']}. {character.get('personality', '')}"}
                ]
                
                for msg in reversed(messages[-5:]):
                    api_messages.append({
                        "role": msg['role'],
                        "content": msg['content']
                    })
                
                api_messages.append({"role": "user", "content": user_input})
                
                response = client.chat.completions.create(
                    model=character.get('model', 'gpt-3.5-turbo'),
                    messages=api_messages,
                    temperature=character.get('temperature', 0.7),
                    max_tokens=character.get('max_tokens', 500)
                )
                
                return {
                    'content': response.choices[0].message.content,
                    'thought_pattern': thought_pattern,
                    'emotion': emotion
                }
        except Exception as e:
            print(f"LLM error: {e}")
        
        # Fallback response
        return {
            'content': f"Hello! I'm {character['name']}. I received your message: \"{user_input[:100]}...\" (Configure OpenAI API key for full responses)",
            'thought_pattern': thought_pattern,
            'emotion': emotion
        }
    
    def get_messages(self, character_id, limit=50):
        """Get messages for a character."""
        return self.data_manager.get_messages(character_id, limit)
    
    def go_back(self):
        """Navigate back."""
        if self.sm.current == 'chat':
            self.sm.current = 'characters'
        elif self.sm.current == 'character_edit':
            self.sm.current = 'characters'
        elif self.sm.current == 'register':
            self.sm.current = 'login'
        elif self.sm.current == 'characters':
            pass  # Stay on characters screen


if __name__ == '__main__':
    SynthChatApp().run()
