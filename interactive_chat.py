#!/usr/bin/env python3
"""
Interactive chat interface for SynthChat.

Run this script to chat with your agents in an interactive session.
"""

import os
import sys
from dotenv import load_dotenv
from synthchat import AgentManager

# Load environment variables
load_dotenv()


def print_header():
    """Print welcome header."""
    print("\n" + "=" * 60)
    print("SynthChat - Interactive Multi-Agent Chat")
    print("=" * 60)
    print()


def print_menu(agents):
    """Print agent selection menu."""
    print("\nAvailable agents:")
    for i, agent_name in enumerate(agents, 1):
        print(f"  {i}. {agent_name}")
    print("  0. Exit")
    print()


def main():
    """Main interactive chat function."""
    print_header()
    
    # Initialize the agent manager
    credentials_path = os.getenv('GOOGLE_CREDENTIALS_PATH', 'credentials.json')
    token_path = os.getenv('GOOGLE_TOKEN_PATH', 'token.json')
    folder_id = os.getenv('AGENT_MEMORY_FOLDER_ID', None)
    
    manager = AgentManager(
        credentials_path=credentials_path,
        token_path=token_path,
        folder_id=folder_id
    )
    
    # Set up LLM client if available
    openai_api_key = os.getenv('OPENAI_API_KEY')
    if openai_api_key:
        try:
            from openai import OpenAI
            client = OpenAI(api_key=openai_api_key)
            manager.set_llm_client(client)
            print("✓ LLM client configured\n")
        except ImportError:
            print("⚠ OpenAI library not available")
            print("  Install with: pip install openai\n")
    
    # Create default agents if none exist
    if not manager.list_agents():
        print("No agents found. Creating default agents...\n")
        manager.create_agent(
            name="Assistant",
            personality="a helpful and friendly AI assistant",
            system_prompt="You are a helpful AI assistant."
        )
        print("✓ Created default agent: Assistant\n")
    
    # Main interaction loop
    while True:
        agents = manager.list_agents()
        print_menu(agents)
        
        try:
            choice = input("Select an agent (number): ").strip()
            
            if choice == "0":
                print("\nGoodbye!\n")
                break
            
            try:
                agent_index = int(choice) - 1
                if agent_index < 0 or agent_index >= len(agents):
                    print("Invalid selection. Please try again.")
                    continue
                
                agent_name = agents[agent_index]
                print(f"\n{'=' * 60}")
                print(f"Chatting with {agent_name}")
                print(f"{'=' * 60}")
                print("Type 'back' to return to agent selection")
                print("Type 'summary' to see agent summary")
                print("Type 'trait <name> <value>' to add a character trait")
                print()
                
                # Agent chat loop
                while True:
                    user_input = input("You: ").strip()
                    
                    if not user_input:
                        continue
                    
                    if user_input.lower() == "back":
                        break
                    
                    if user_input.lower() == "summary":
                        summary = manager.get_agent_summary(agent_name)
                        print(f"\n{agent_name} Summary:")
                        print(f"  Personality: {summary['personality']}")
                        print(f"  Total Interactions: {summary['total_interactions']}")
                        print(f"  Character Traits: {', '.join(summary['character_traits']) or 'None'}")
                        print()
                        continue
                    
                    if user_input.lower().startswith("trait "):
                        parts = user_input[6:].split(maxsplit=1)
                        if len(parts) >= 2:
                            trait_name, trait_value = parts
                            manager.add_agent_trait(agent_name, trait_name, trait_value)
                            print(f"✓ Trait '{trait_name}' added\n")
                        else:
                            print("Usage: trait <name> <value>\n")
                        continue
                    
                    # Process interaction
                    response = manager.chat_with_agent(agent_name, user_input)
                    print(f"\n{agent_name}: {response}\n")
            
            except ValueError:
                print("Invalid input. Please enter a number.")
                continue
        
        except KeyboardInterrupt:
            print("\n\nGoodbye!\n")
            break
        except Exception as e:
            print(f"\nError: {e}\n")
            continue


if __name__ == "__main__":
    main()
