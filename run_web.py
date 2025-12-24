#!/usr/bin/env python3
"""
Run the SynthChat Web Application.

This script starts the Flask web server with the Silly Tavern-style interface.
"""

import os
import sys

# Add the workspace to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from web.app import app, init_db, socketio

if __name__ == '__main__':
    # Initialize database
    print("Initializing database...")
    init_db()
    print("Database initialized!")
    
    # Get configuration
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    host = os.getenv('HOST', '0.0.0.0')
    
    print(f"\n{'='*60}")
    print("SynthChat Web - Silly Tavern Style LLM Manager")
    print(f"{'='*60}")
    print(f"\nServer starting on http://{host}:{port}")
    print("\nFeatures:")
    print("  - Multiple AI characters with unique personalities")
    print("  - Character cards and chat bubble interface")
    print("  - Google Drive integration for memory persistence")
    print("  - User authentication")
    print("\nPress Ctrl+C to stop the server")
    print(f"{'='*60}\n")
    
    # Run the server
    socketio.run(app, host=host, port=port, debug=debug)
