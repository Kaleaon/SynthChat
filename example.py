#!/usr/bin/env python3
"""
Example script demonstrating the SynthChat multi-agent system.

This script shows how to:
1. Create multiple AI agents
2. Chat with different agents
3. Track character development
4. Store memories in Google Drive
"""

import os
from dotenv import load_dotenv
from synthchat import AgentManager

# Load environment variables
load_dotenv()


def main():
    """Main example function."""
    print("=" * 60)
    print("SynthChat - Multi-Agent LLM Manager Example")
    print("=" * 60)
    print()
    
    # Initialize the agent manager
    # It will automatically connect to Google Drive if credentials are available
    credentials_path = os.getenv('GOOGLE_CREDENTIALS_PATH', 'credentials.json')
    token_path = os.getenv('GOOGLE_TOKEN_PATH', 'token.json')
    folder_id = os.getenv('AGENT_MEMORY_FOLDER_ID', None)
    
    manager = AgentManager(
        credentials_path=credentials_path,
        token_path=token_path,
        folder_id=folder_id
    )
    
    # Optional: Set up LLM client (e.g., OpenAI)
    openai_api_key = os.getenv('OPENAI_API_KEY')
    if openai_api_key:
        try:
            from openai import OpenAI
            client = OpenAI(api_key=openai_api_key)
            manager.set_llm_client(client)
            print("✓ OpenAI client configured\n")
        except ImportError:
            print("⚠ OpenAI library not available. Install with: pip install openai")
            print("  Agents will use fallback responses\n")
    else:
        print("⚠ No OpenAI API key found. Agents will use fallback responses\n")
    
    # Create multiple agents with different personalities
    print("Creating AI agents...\n")
    
    # Agent 1: A helpful assistant
    if "Alice" not in manager.list_agents():
        alice = manager.create_agent(
            name="Alice",
            personality="a helpful and friendly AI assistant who loves to help people learn",
            system_prompt="You are Alice, a friendly and knowledgeable assistant. You're patient, encouraging, and always ready to help.",
            temperature=0.7
        )
        print(f"✓ Created agent: Alice\n")
    
    # Agent 2: A creative storyteller
    if "Bob" not in manager.list_agents():
        bob = manager.create_agent(
            name="Bob",
            personality="a creative storyteller with a vivid imagination",
            system_prompt="You are Bob, a creative storyteller. You love crafting engaging narratives and bringing stories to life.",
            temperature=0.9
        )
        print(f"✓ Created agent: Bob\n")
    
    # Agent 3: A technical expert
    if "Carol" not in manager.list_agents():
        carol = manager.create_agent(
            name="Carol",
            personality="a technical expert who explains complex topics clearly",
            system_prompt="You are Carol, a technical expert. You excel at breaking down complex topics into understandable explanations.",
            temperature=0.5
        )
        print(f"✓ Created agent: Carol\n")
    
    # List all agents
    print("Active agents:", ", ".join(manager.list_agents()))
    print()
    
    # Example interactions
    print("-" * 60)
    print("Example Interactions")
    print("-" * 60)
    print()
    
    # Chat with Alice
    print("💬 User -> Alice: Hello! Can you help me learn Python?")
    response = manager.chat_with_agent("Alice", "Hello! Can you help me learn Python?")
    print(f"🤖 Alice: {response}\n")
    
    # Add character trait to Alice
    manager.add_agent_trait("Alice", "expertise", "Python programming", 
                           "Demonstrated knowledge in Python")
    
    # Chat with Bob
    print("💬 User -> Bob: Tell me a short story about a robot")
    response = manager.chat_with_agent("Bob", "Tell me a short story about a robot")
    print(f"🤖 Bob: {response}\n")
    
    # Add character trait to Bob
    manager.add_agent_trait("Bob", "creativity", "high", 
                           "Creates engaging robot stories")
    
    # Chat with Carol
    print("💬 User -> Carol: What is machine learning?")
    response = manager.chat_with_agent("Carol", "What is machine learning?")
    print(f"🤖 Carol: {response}\n")
    
    # Get agent summaries
    print("-" * 60)
    print("Agent Summaries")
    print("-" * 60)
    print()
    
    for agent_name in manager.list_agents():
        summary = manager.get_agent_summary(agent_name)
        print(f"Agent: {summary['name']}")
        print(f"  Personality: {summary['personality']}")
        print(f"  Total Interactions: {summary['total_interactions']}")
        print(f"  Character Traits: {', '.join(summary['character_traits']) or 'None'}")
        if summary.get('drive_files'):
            print(f"  Google Drive: ✓ Connected")
            print(f"    Folder ID: {summary['drive_files']['folder_id']}")
        else:
            print(f"  Google Drive: ✗ Not connected")
        print()
    
    # Export an agent
    print("-" * 60)
    print("Export/Import Demo")
    print("-" * 60)
    print()
    
    export_path = "/tmp/alice_export.json"
    manager.export_agent("Alice", export_path)
    print(f"✓ Alice exported to {export_path}\n")
    
    print("=" * 60)
    print("Example completed!")
    print()
    print("Your agents are now running with:")
    print("  - Individual memory storage")
    print("  - Character development tracking")
    print("  - Private thought patterns")
    if manager.storage:
        print("  - Google Drive persistence ✓")
    else:
        print("  - Google Drive persistence ✗ (credentials needed)")
    print("=" * 60)


if __name__ == "__main__":
    main()
