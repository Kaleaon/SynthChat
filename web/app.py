"""
Main Flask application for SynthChat Web.
A Silly Tavern style LLM manager with Google Drive integration.
"""

import os
import json
import uuid
from datetime import datetime
from functools import wraps

from flask import Flask, render_template, request, jsonify, redirect, url_for, send_from_directory
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
from werkzeug.utils import secure_filename
from dotenv import load_dotenv

from web.models import db, bcrypt, User, Character, Conversation, Message

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__, 
            template_folder='templates',
            static_folder='static')

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'synthchat-secret-key-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///synthchat.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max upload
app.config['UPLOAD_FOLDER'] = os.path.join(os.path.dirname(__file__), 'static', 'avatars')

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Initialize extensions
db.init_app(app)
bcrypt.init_app(app)
CORS(app, supports_credentials=True)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# Login manager
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login_page'

# LLM Client (initialized on first use)
llm_client = None


def get_llm_client():
    """Get or initialize the LLM client."""
    global llm_client
    if llm_client is None:
        api_key = os.getenv('OPENAI_API_KEY')
        if api_key:
            try:
                from openai import OpenAI
                llm_client = OpenAI(api_key=api_key)
            except ImportError:
                print("OpenAI library not available")
    return llm_client


@login_manager.user_loader
def load_user(user_id):
    """Load user by ID for Flask-Login."""
    return User.query.get(int(user_id))


def api_login_required(f):
    """Decorator for API endpoints requiring authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated:
            return jsonify({'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated_function


# =============================================================================
# Page Routes
# =============================================================================

@app.route('/')
def index():
    """Home page - redirects to chat if logged in, otherwise to login."""
    if current_user.is_authenticated:
        return redirect(url_for('chat_page'))
    return redirect(url_for('login_page'))


@app.route('/login')
def login_page():
    """Login page."""
    if current_user.is_authenticated:
        return redirect(url_for('chat_page'))
    return render_template('login.html')


@app.route('/register')
def register_page():
    """Registration page."""
    if current_user.is_authenticated:
        return redirect(url_for('chat_page'))
    return render_template('register.html')


@app.route('/chat')
@login_required
def chat_page():
    """Main chat interface."""
    return render_template('chat.html')


@app.route('/characters')
@login_required
def characters_page():
    """Character management page."""
    return render_template('characters.html')


# =============================================================================
# Authentication API
# =============================================================================

@app.route('/api/auth/register', methods=['POST'])
def api_register():
    """Register a new user."""
    data = request.get_json()
    
    username = data.get('username', '').strip()
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    
    # Validation
    if not username or len(username) < 3:
        return jsonify({'error': 'Username must be at least 3 characters'}), 400
    if not email or '@' not in email:
        return jsonify({'error': 'Valid email is required'}), 400
    if not password or len(password) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400
    
    # Check for existing user
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Username already taken'}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Email already registered'}), 400
    
    # Create user
    user = User(username=username, email=email)
    user.set_password(password)
    
    db.session.add(user)
    db.session.commit()
    
    # Log in the new user
    login_user(user)
    
    return jsonify({
        'message': 'Registration successful',
        'user': user.to_dict()
    })


@app.route('/api/auth/login', methods=['POST'])
def api_login():
    """Log in a user."""
    data = request.get_json()
    
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    # Find user by username or email
    user = User.query.filter(
        (User.username == username) | (User.email == username.lower())
    ).first()
    
    if not user or not user.check_password(password):
        return jsonify({'error': 'Invalid username or password'}), 401
    
    # Update last login
    user.last_login = datetime.utcnow()
    db.session.commit()
    
    # Log in the user
    login_user(user, remember=True)
    
    return jsonify({
        'message': 'Login successful',
        'user': user.to_dict()
    })


@app.route('/api/auth/logout', methods=['POST'])
@api_login_required
def api_logout():
    """Log out the current user."""
    logout_user()
    return jsonify({'message': 'Logged out successfully'})


@app.route('/api/auth/me', methods=['GET'])
@api_login_required
def api_current_user():
    """Get current user info."""
    return jsonify({'user': current_user.to_dict()})


# =============================================================================
# Character API
# =============================================================================

@app.route('/api/characters', methods=['GET'])
@api_login_required
def api_list_characters():
    """List all characters for current user."""
    characters = Character.query.filter_by(user_id=current_user.id).all()
    return jsonify({
        'characters': [c.to_dict() for c in characters]
    })


@app.route('/api/characters', methods=['POST'])
@api_login_required
def api_create_character():
    """Create a new character."""
    data = request.get_json()
    
    name = data.get('name', '').strip()
    if not name:
        return jsonify({'error': 'Character name is required'}), 400
    
    # Check for duplicate name
    existing = Character.query.filter_by(user_id=current_user.id, name=name).first()
    if existing:
        return jsonify({'error': f'Character "{name}" already exists'}), 400
    
    character = Character(
        user_id=current_user.id,
        name=name,
        description=data.get('description', ''),
        personality=data.get('personality', ''),
        system_prompt=data.get('system_prompt', f'You are {name}. {data.get("personality", "")}'),
        greeting=data.get('greeting', f'Hello! I\'m {name}. How can I help you today?'),
        avatar_url=data.get('avatar_url', '/static/avatars/default.png'),
        model=data.get('model', 'gpt-3.5-turbo'),
        temperature=data.get('temperature', 0.7),
        max_tokens=data.get('max_tokens', 500)
    )
    
    # Set traits if provided
    if data.get('traits'):
        character.set_traits(data['traits'])
    
    db.session.add(character)
    db.session.commit()
    
    # Initialize Google Drive storage if available
    try:
        from synthchat.google_drive_storage import GoogleDriveStorage
        credentials_path = os.getenv('GOOGLE_CREDENTIALS_PATH', 'credentials.json')
        token_path = os.getenv('GOOGLE_TOKEN_PATH', 'token.json')
        
        if os.path.exists(credentials_path):
            storage = GoogleDriveStorage(credentials_path=credentials_path, token_path=token_path)
            drive_files = storage.get_or_create_agent_files(character.name)
            
            character.drive_folder_id = drive_files.get('folder_id')
            character.drive_memory_doc_id = drive_files.get('memory_doc_id')
            character.drive_thoughts_doc_id = drive_files.get('thoughts_doc_id')
            character.drive_sheet_id = drive_files.get('sheet_id')
            
            db.session.commit()
    except Exception as e:
        print(f"Could not initialize Google Drive for character: {e}")
    
    return jsonify({
        'message': f'Character "{name}" created successfully',
        'character': character.to_dict()
    }), 201


@app.route('/api/characters/<int:character_id>', methods=['GET'])
@api_login_required
def api_get_character(character_id):
    """Get a specific character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    return jsonify({'character': character.to_dict(include_conversations=True)})


@app.route('/api/characters/<int:character_id>', methods=['PUT'])
@api_login_required
def api_update_character(character_id):
    """Update a character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    data = request.get_json()
    
    # Update fields
    if 'name' in data:
        character.name = data['name'].strip()
    if 'description' in data:
        character.description = data['description']
    if 'personality' in data:
        character.personality = data['personality']
    if 'system_prompt' in data:
        character.system_prompt = data['system_prompt']
    if 'greeting' in data:
        character.greeting = data['greeting']
    if 'avatar_url' in data:
        character.avatar_url = data['avatar_url']
    if 'model' in data:
        character.model = data['model']
    if 'temperature' in data:
        character.temperature = float(data['temperature'])
    if 'max_tokens' in data:
        character.max_tokens = int(data['max_tokens'])
    if 'traits' in data:
        character.set_traits(data['traits'])
    
    db.session.commit()
    
    return jsonify({
        'message': 'Character updated successfully',
        'character': character.to_dict()
    })


@app.route('/api/characters/<int:character_id>', methods=['DELETE'])
@api_login_required
def api_delete_character(character_id):
    """Delete a character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    name = character.name
    db.session.delete(character)
    db.session.commit()
    
    return jsonify({'message': f'Character "{name}" deleted successfully'})


@app.route('/api/characters/<int:character_id>/traits', methods=['POST'])
@api_login_required
def api_add_character_trait(character_id):
    """Add a trait to a character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    data = request.get_json()
    trait_name = data.get('name', '').strip()
    trait_value = data.get('value', '').strip()
    notes = data.get('notes', '')
    
    if not trait_name or not trait_value:
        return jsonify({'error': 'Trait name and value are required'}), 400
    
    character.add_trait(trait_name, trait_value, notes)
    db.session.commit()
    
    return jsonify({
        'message': f'Trait "{trait_name}" added',
        'traits': character.get_traits()
    })


# =============================================================================
# Avatar Upload API
# =============================================================================

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}


def allowed_file(filename):
    """Check if file extension is allowed."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/api/generate/avatar', methods=['POST'])
@api_login_required
def api_generate_avatar():
    """Generate an avatar for a character."""
    from web.avatar_generator import generate_procedural_avatar, generate_ai_avatar
    
    data = request.get_json()
    name = data.get('name', 'Character')
    use_ai = data.get('use_ai', False)
    prompt = data.get('prompt', '')
    
    # Generate unique filename
    filename = f"{uuid.uuid4().hex}.png"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    avatar_path = None
    
    if use_ai and prompt:
        # Try AI generation first
        avatar_path = generate_ai_avatar(prompt, filepath)
    
    if not avatar_path:
        # Fall back to procedural generation
        avatar_path = generate_procedural_avatar(name, output_path=filepath)
    
    if avatar_path:
        return jsonify({
            'message': 'Avatar generated successfully',
            'avatar_url': f'/static/avatars/{filename}'
        })
    else:
        return jsonify({'error': 'Could not generate avatar'}), 500


@app.route('/api/upload/avatar', methods=['POST'])
@api_login_required
def api_upload_avatar():
    """Upload an avatar image."""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if not allowed_file(file.filename):
        return jsonify({'error': 'File type not allowed. Use PNG, JPG, GIF, or WebP'}), 400
    
    # Generate unique filename
    ext = file.filename.rsplit('.', 1)[1].lower()
    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    # Save file
    file.save(filepath)
    
    # Optionally resize image
    try:
        from PIL import Image
        img = Image.open(filepath)
        img.thumbnail((512, 512), Image.Resampling.LANCZOS)
        img.save(filepath, quality=85, optimize=True)
    except Exception as e:
        print(f"Could not resize image: {e}")
    
    avatar_url = f'/static/avatars/{filename}'
    
    return jsonify({
        'message': 'Avatar uploaded successfully',
        'avatar_url': avatar_url
    })


# =============================================================================
# Conversation API
# =============================================================================

@app.route('/api/characters/<int:character_id>/conversations', methods=['GET'])
@api_login_required
def api_list_conversations(character_id):
    """List all conversations for a character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    conversations = Conversation.query.filter_by(character_id=character_id).order_by(
        Conversation.updated_at.desc()
    ).all()
    
    return jsonify({
        'conversations': [c.to_dict() for c in conversations]
    })


@app.route('/api/characters/<int:character_id>/conversations', methods=['POST'])
@api_login_required
def api_create_conversation(character_id):
    """Create a new conversation with a character."""
    character = Character.query.filter_by(id=character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Character not found'}), 404
    
    data = request.get_json() or {}
    title = data.get('title', f'Chat with {character.name}')
    
    conversation = Conversation(character_id=character_id, title=title)
    db.session.add(conversation)
    db.session.commit()
    
    # Add greeting message if character has one
    if character.greeting:
        greeting_msg = Message(
            conversation_id=conversation.id,
            role='assistant',
            content=character.greeting,
            emotion='friendly'
        )
        db.session.add(greeting_msg)
        db.session.commit()
    
    return jsonify({
        'message': 'Conversation created',
        'conversation': conversation.to_dict(include_messages=True)
    }), 201


@app.route('/api/conversations/<int:conversation_id>', methods=['GET'])
@api_login_required
def api_get_conversation(conversation_id):
    """Get a conversation with messages."""
    conversation = Conversation.query.get(conversation_id)
    if not conversation:
        return jsonify({'error': 'Conversation not found'}), 404
    
    # Check ownership
    character = Character.query.filter_by(id=conversation.character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Access denied'}), 403
    
    return jsonify({
        'conversation': conversation.to_dict(include_messages=True),
        'character': character.to_dict()
    })


@app.route('/api/conversations/<int:conversation_id>', methods=['DELETE'])
@api_login_required
def api_delete_conversation(conversation_id):
    """Delete a conversation."""
    conversation = Conversation.query.get(conversation_id)
    if not conversation:
        return jsonify({'error': 'Conversation not found'}), 404
    
    # Check ownership
    character = Character.query.filter_by(id=conversation.character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Access denied'}), 403
    
    db.session.delete(conversation)
    db.session.commit()
    
    return jsonify({'message': 'Conversation deleted'})


# =============================================================================
# Chat API
# =============================================================================

def generate_thought_pattern(user_input, character, history_count):
    """Generate internal thought pattern for the character."""
    thoughts = []
    
    if '?' in user_input:
        thoughts.append("The user is asking a question")
    if len(user_input.split()) > 20:
        thoughts.append("This is a detailed message requiring careful consideration")
    if history_count > 0:
        thoughts.append(f"Building on our previous {history_count} interactions")
    
    # Add personality-based thoughts
    if character.personality:
        personality_lower = character.personality.lower()
        if 'creative' in personality_lower:
            thoughts.append("Thinking of creative ways to respond")
        if 'technical' in personality_lower:
            thoughts.append("Considering technical aspects")
        if 'friendly' in personality_lower:
            thoughts.append("Keeping a warm, friendly tone")
    
    return " | ".join(thoughts) if thoughts else "Processing new input"


def determine_emotion(user_input, response):
    """Determine emotional state based on interaction."""
    user_lower = user_input.lower()
    
    if any(word in user_lower for word in ['happy', 'great', 'excellent', 'wonderful', 'thanks', 'thank you']):
        return 'happy'
    elif any(word in user_lower for word in ['sad', 'upset', 'angry', 'frustrated']):
        return 'empathetic'
    elif any(word in user_lower for word in ['help', 'how', 'what', 'why', 'when']):
        return 'helpful'
    elif '?' in user_input:
        return 'curious'
    else:
        return 'neutral'


@app.route('/api/conversations/<int:conversation_id>/messages', methods=['POST'])
@api_login_required
def api_send_message(conversation_id):
    """Send a message in a conversation and get a response."""
    conversation = Conversation.query.get(conversation_id)
    if not conversation:
        return jsonify({'error': 'Conversation not found'}), 404
    
    # Check ownership
    character = Character.query.filter_by(id=conversation.character_id, user_id=current_user.id).first()
    if not character:
        return jsonify({'error': 'Access denied'}), 403
    
    data = request.get_json()
    user_content = data.get('content', '').strip()
    
    if not user_content:
        return jsonify({'error': 'Message content is required'}), 400
    
    # Save user message
    user_message = Message(
        conversation_id=conversation_id,
        role='user',
        content=user_content
    )
    db.session.add(user_message)
    
    # Generate response
    history_count = Message.query.filter_by(conversation_id=conversation_id).count()
    thought_pattern = generate_thought_pattern(user_content, character, history_count)
    
    # Try to get LLM response
    client = get_llm_client()
    if client:
        try:
            # Build messages for LLM
            messages = [
                {"role": "system", "content": character.system_prompt or f"You are {character.name}. {character.personality}"}
            ]
            
            # Add recent conversation history
            recent_messages = Message.query.filter_by(conversation_id=conversation_id).order_by(
                Message.created_at.desc()
            ).limit(10).all()
            recent_messages.reverse()
            
            for msg in recent_messages:
                messages.append({"role": msg.role, "content": msg.content})
            
            # Add current message
            messages.append({"role": "user", "content": user_content})
            
            # Call LLM
            response = client.chat.completions.create(
                model=character.model,
                messages=messages,
                temperature=character.temperature,
                max_tokens=character.max_tokens
            )
            assistant_content = response.choices[0].message.content
        except Exception as e:
            print(f"LLM error: {e}")
            assistant_content = f"[{character.name}]: I understand you said '{user_content[:50]}...' (LLM temporarily unavailable)"
    else:
        # Fallback response
        assistant_content = f"Hello! I'm {character.name}. I received your message: '{user_content[:100]}...' (Configure OpenAI API key for full responses)"
    
    # Determine emotion
    emotion = determine_emotion(user_content, assistant_content)
    
    # Save assistant message
    assistant_message = Message(
        conversation_id=conversation_id,
        role='assistant',
        content=assistant_content,
        thought_pattern=thought_pattern,
        emotion=emotion
    )
    db.session.add(assistant_message)
    
    # Update conversation timestamp
    conversation.updated_at = datetime.utcnow()
    
    db.session.commit()
    
    # Save to Google Drive if available
    try:
        if character.drive_sheet_id:
            from synthchat.google_drive_storage import GoogleDriveStorage
            credentials_path = os.getenv('GOOGLE_CREDENTIALS_PATH', 'credentials.json')
            token_path = os.getenv('GOOGLE_TOKEN_PATH', 'token.json')
            
            if os.path.exists(credentials_path):
                storage = GoogleDriveStorage(credentials_path=credentials_path, token_path=token_path)
                storage.append_interaction(character.drive_sheet_id, {
                    'timestamp': datetime.utcnow().isoformat(),
                    'user_input': user_content,
                    'agent_response': assistant_content,
                    'thought_pattern': thought_pattern,
                    'emotion': emotion,
                    'context': f'Conversation {conversation_id}'
                })
    except Exception as e:
        print(f"Could not save to Google Drive: {e}")
    
    return jsonify({
        'user_message': user_message.to_dict(),
        'assistant_message': assistant_message.to_dict()
    })


# =============================================================================
# WebSocket for Real-time Chat
# =============================================================================

@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection."""
    if current_user.is_authenticated:
        emit('connected', {'user': current_user.username})
    else:
        emit('error', {'message': 'Authentication required'})


@socketio.on('join_conversation')
def handle_join(data):
    """Join a conversation room."""
    conversation_id = data.get('conversation_id')
    if conversation_id:
        join_room(f'conversation_{conversation_id}')
        emit('joined', {'conversation_id': conversation_id})


@socketio.on('leave_conversation')
def handle_leave(data):
    """Leave a conversation room."""
    conversation_id = data.get('conversation_id')
    if conversation_id:
        leave_room(f'conversation_{conversation_id}')


# =============================================================================
# Static Files
# =============================================================================

@app.route('/static/avatars/<filename>')
def serve_avatar(filename):
    """Serve avatar images."""
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


# =============================================================================
# Database Initialization
# =============================================================================

def init_db():
    """Initialize the database and create tables."""
    with app.app_context():
        db.create_all()
        
        # Create default avatar if it doesn't exist
        default_avatar_path = os.path.join(app.config['UPLOAD_FOLDER'], 'default.png')
        if not os.path.exists(default_avatar_path):
            # Create a simple default avatar
            try:
                from PIL import Image, ImageDraw
                img = Image.new('RGB', (256, 256), color=(100, 100, 150))
                draw = ImageDraw.Draw(img)
                draw.ellipse([64, 64, 192, 192], fill=(200, 200, 220))
                img.save(default_avatar_path)
            except Exception as e:
                print(f"Could not create default avatar: {e}")


# =============================================================================
# Main Entry Point
# =============================================================================

if __name__ == '__main__':
    init_db()
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    socketio.run(app, host='0.0.0.0', port=port, debug=debug)
