"""
Tests for the SynthChat Web Application.

These tests verify the web interface functionality.
"""

import unittest
import tempfile
import os
import json

# Set up test environment before importing app
os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
os.environ['SECRET_KEY'] = 'test-secret-key'

from web.app import app, db, init_db
from web.models import User, Character, Conversation, Message


class TestWebApp(unittest.TestCase):
    """Test the Flask web application."""
    
    def setUp(self):
        """Set up test client and database."""
        app.config['TESTING'] = True
        app.config['WTF_CSRF_ENABLED'] = False
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        
        self.client = app.test_client()
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        """Clean up database."""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_index_redirects_to_login(self):
        """Test that unauthenticated users are redirected to login."""
        response = self.client.get('/')
        self.assertEqual(response.status_code, 302)
        self.assertIn('/login', response.location)
    
    def test_login_page_loads(self):
        """Test that login page loads correctly."""
        response = self.client.get('/login')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'SynthChat', response.data)
    
    def test_register_page_loads(self):
        """Test that register page loads correctly."""
        response = self.client.get('/register')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Create your account', response.data)
    
    def test_user_registration(self):
        """Test user registration."""
        response = self.client.post('/api/auth/register', 
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['user']['username'], 'testuser')
    
    def test_user_login(self):
        """Test user login."""
        # First register
        self.client.post('/api/auth/register',
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        # Then logout
        self.client.post('/api/auth/logout')
        
        # Then login
        response = self.client.post('/api/auth/login',
            data=json.dumps({
                'username': 'testuser',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['message'], 'Login successful')
    
    def test_invalid_login(self):
        """Test login with invalid credentials."""
        response = self.client.post('/api/auth/login',
            data=json.dumps({
                'username': 'nonexistent',
                'password': 'wrongpassword'
            }),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 401)
    
    def test_create_character(self):
        """Test character creation."""
        # Register and login
        self.client.post('/api/auth/register',
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        # Create character
        response = self.client.post('/api/characters',
            data=json.dumps({
                'name': 'TestBot',
                'personality': 'friendly and helpful',
                'greeting': 'Hello there!'
            }),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['character']['name'], 'TestBot')
    
    def test_list_characters(self):
        """Test listing characters."""
        # Register and create character
        self.client.post('/api/auth/register',
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        self.client.post('/api/characters',
            data=json.dumps({'name': 'Bot1'}),
            content_type='application/json'
        )
        
        self.client.post('/api/characters',
            data=json.dumps({'name': 'Bot2'}),
            content_type='application/json'
        )
        
        # List characters
        response = self.client.get('/api/characters')
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(len(data['characters']), 2)
    
    def test_create_conversation(self):
        """Test conversation creation."""
        # Setup
        self.client.post('/api/auth/register',
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        char_response = self.client.post('/api/characters',
            data=json.dumps({'name': 'TestBot', 'greeting': 'Hello!'}),
            content_type='application/json'
        )
        char_id = json.loads(char_response.data)['character']['id']
        
        # Create conversation
        response = self.client.post(f'/api/characters/{char_id}/conversations',
            data=json.dumps({'title': 'Test Chat'}),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['conversation']['title'], 'Test Chat')
        # Should have greeting message
        self.assertEqual(len(data['conversation']['messages']), 1)
    
    def test_send_message(self):
        """Test sending a message in a conversation."""
        # Setup
        self.client.post('/api/auth/register',
            data=json.dumps({
                'username': 'testuser',
                'email': 'test@example.com',
                'password': 'password123'
            }),
            content_type='application/json'
        )
        
        char_response = self.client.post('/api/characters',
            data=json.dumps({'name': 'TestBot'}),
            content_type='application/json'
        )
        char_id = json.loads(char_response.data)['character']['id']
        
        conv_response = self.client.post(f'/api/characters/{char_id}/conversations',
            data=json.dumps({}),
            content_type='application/json'
        )
        conv_id = json.loads(conv_response.data)['conversation']['id']
        
        # Send message
        response = self.client.post(f'/api/conversations/{conv_id}/messages',
            data=json.dumps({'content': 'Hello, TestBot!'}),
            content_type='application/json'
        )
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['user_message']['content'], 'Hello, TestBot!')
        self.assertIsNotNone(data['assistant_message']['content'])


class TestUserModel(unittest.TestCase):
    """Test the User model."""
    
    def setUp(self):
        """Set up test database."""
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        """Clean up database."""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_password_hashing(self):
        """Test password hashing."""
        with app.app_context():
            user = User(username='test', email='test@test.com')
            user.set_password('testpassword')
            
            self.assertTrue(user.check_password('testpassword'))
            self.assertFalse(user.check_password('wrongpassword'))
    
    def test_user_to_dict(self):
        """Test user serialization."""
        with app.app_context():
            user = User(username='test', email='test@test.com')
            user.set_password('testpassword')
            db.session.add(user)
            db.session.commit()
            
            user_dict = user.to_dict()
            
            self.assertEqual(user_dict['username'], 'test')
            self.assertEqual(user_dict['email'], 'test@test.com')
            self.assertNotIn('password_hash', user_dict)


class TestCharacterModel(unittest.TestCase):
    """Test the Character model."""
    
    def setUp(self):
        """Set up test database."""
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        
        with app.app_context():
            db.create_all()
            
            # Create test user
            user = User(username='test', email='test@test.com')
            user.set_password('test')
            db.session.add(user)
            db.session.commit()
            self.user_id = user.id
    
    def tearDown(self):
        """Clean up database."""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_character_creation(self):
        """Test character creation."""
        with app.app_context():
            char = Character(
                user_id=self.user_id,
                name='TestBot',
                personality='friendly'
            )
            db.session.add(char)
            db.session.commit()
            
            self.assertEqual(char.name, 'TestBot')
            self.assertEqual(char.personality, 'friendly')
    
    def test_character_traits(self):
        """Test character trait management."""
        with app.app_context():
            char = Character(
                user_id=self.user_id,
                name='TestBot'
            )
            db.session.add(char)
            db.session.commit()
            
            # Add trait
            char.add_trait('knowledge', 'high', 'Very smart')
            db.session.commit()
            
            traits = char.get_traits()
            self.assertIn('knowledge', traits)
            self.assertEqual(traits['knowledge']['value'], 'high')


if __name__ == '__main__':
    unittest.main()
