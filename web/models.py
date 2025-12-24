"""
Database models for SynthChat Web.
"""

from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from flask_bcrypt import Bcrypt
import json

db = SQLAlchemy()
bcrypt = Bcrypt()


class User(UserMixin, db.Model):
    """User model for authentication."""
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    # Relationships
    characters = db.relationship('Character', backref='owner', lazy=True, cascade='all, delete-orphan')
    
    def set_password(self, password):
        """Hash and set the user's password."""
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')
    
    def check_password(self, password):
        """Check if the provided password matches the hash."""
        return bcrypt.check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        """Convert user to dictionary (excluding sensitive data)."""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'character_count': len(self.characters)
        }


class Character(db.Model):
    """Character/Agent model with avatar and personality."""
    __tablename__ = 'characters'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    
    # Basic info
    name = db.Column(db.String(100), nullable=False)
    avatar_url = db.Column(db.String(500), default='/static/avatars/default.png')
    description = db.Column(db.Text, default='')
    
    # Personality & LLM settings
    personality = db.Column(db.Text, default='')
    system_prompt = db.Column(db.Text, default='')
    greeting = db.Column(db.Text, default='Hello! How can I help you today?')
    
    # LLM configuration
    model = db.Column(db.String(50), default='gpt-3.5-turbo')
    temperature = db.Column(db.Float, default=0.7)
    max_tokens = db.Column(db.Integer, default=500)
    
    # Character traits (stored as JSON)
    traits = db.Column(db.Text, default='{}')
    
    # Google Drive integration
    drive_folder_id = db.Column(db.String(200))
    drive_memory_doc_id = db.Column(db.String(200))
    drive_thoughts_doc_id = db.Column(db.String(200))
    drive_sheet_id = db.Column(db.String(200))
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    conversations = db.relationship('Conversation', backref='character', lazy=True, cascade='all, delete-orphan')
    
    def get_traits(self):
        """Get character traits as dictionary."""
        try:
            return json.loads(self.traits) if self.traits else {}
        except:
            return {}
    
    def set_traits(self, traits_dict):
        """Set character traits from dictionary."""
        self.traits = json.dumps(traits_dict)
    
    def add_trait(self, name, value, notes=''):
        """Add or update a character trait."""
        traits = self.get_traits()
        traits[name] = {
            'value': value,
            'notes': notes,
            'updated': datetime.utcnow().isoformat()
        }
        self.set_traits(traits)
    
    def to_dict(self, include_conversations=False):
        """Convert character to dictionary."""
        data = {
            'id': self.id,
            'name': self.name,
            'avatar_url': self.avatar_url,
            'description': self.description,
            'personality': self.personality,
            'system_prompt': self.system_prompt,
            'greeting': self.greeting,
            'model': self.model,
            'temperature': self.temperature,
            'max_tokens': self.max_tokens,
            'traits': self.get_traits(),
            'drive_connected': bool(self.drive_folder_id),
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'conversation_count': len(self.conversations)
        }
        
        if include_conversations:
            data['conversations'] = [c.to_dict() for c in self.conversations]
        
        return data


class Conversation(db.Model):
    """Conversation session with a character."""
    __tablename__ = 'conversations'
    
    id = db.Column(db.Integer, primary_key=True)
    character_id = db.Column(db.Integer, db.ForeignKey('characters.id'), nullable=False)
    title = db.Column(db.String(200), default='New Conversation')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    messages = db.relationship('Message', backref='conversation', lazy=True, 
                              order_by='Message.created_at', cascade='all, delete-orphan')
    
    def to_dict(self, include_messages=False):
        """Convert conversation to dictionary."""
        data = {
            'id': self.id,
            'character_id': self.character_id,
            'title': self.title,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'message_count': len(self.messages)
        }
        
        if include_messages:
            data['messages'] = [m.to_dict() for m in self.messages]
        
        return data


class Message(db.Model):
    """Individual message in a conversation."""
    __tablename__ = 'messages'
    
    id = db.Column(db.Integer, primary_key=True)
    conversation_id = db.Column(db.Integer, db.ForeignKey('conversations.id'), nullable=False)
    
    role = db.Column(db.String(20), nullable=False)  # 'user' or 'assistant'
    content = db.Column(db.Text, nullable=False)
    
    # Agent-specific fields
    thought_pattern = db.Column(db.Text, default='')
    emotion = db.Column(db.String(50), default='neutral')
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """Convert message to dictionary."""
        return {
            'id': self.id,
            'conversation_id': self.conversation_id,
            'role': self.role,
            'content': self.content,
            'thought_pattern': self.thought_pattern,
            'emotion': self.emotion,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
