"""
Agent Manager - Manages multiple AI agents in a Silly Tavern style system.
"""

import os
import json
from typing import Dict, List, Optional, Any
from pathlib import Path

from synthchat.agent import Agent, AgentConfig
from synthchat.google_drive_storage import GoogleDriveStorage


class AgentManager:
    """
    Manages multiple AI agents with Google Drive integration.
    
    This is the main interface for the multi-agent LLM system,
    similar to Silly Tavern's character management.
    """
    
    def __init__(self, 
                 credentials_path: str = "credentials.json",
                 token_path: str = "token.json",
                 folder_id: Optional[str] = None,
                 config_file: str = "agents_config.json"):
        """
        Initialize the agent manager.
        
        Args:
            credentials_path: Path to Google API credentials
            token_path: Path to token file
            folder_id: Optional parent folder for all agents
            config_file: Path to agents configuration file
        """
        self.config_file = config_file
        self.agents: Dict[str, Agent] = {}
        self.storage: Optional[GoogleDriveStorage] = None
        self.llm_client = None
        
        # Initialize Google Drive storage if credentials exist
        if os.path.exists(credentials_path):
            try:
                self.storage = GoogleDriveStorage(
                    credentials_path=credentials_path,
                    token_path=token_path,
                    folder_id=folder_id
                )
                print("Google Drive storage initialized successfully")
            except Exception as e:
                print(f"Warning: Could not initialize Google Drive storage: {e}")
                print("Agents will work without persistent storage")
        else:
            print(f"Warning: Credentials file not found at {credentials_path}")
            print("Agents will work without Google Drive integration")
        
        # Load existing agents from config
        self._load_agents_config()
    
    def set_llm_client(self, client):
        """
        Set the LLM client for all agents.
        
        Args:
            client: LLM client (e.g., OpenAI client)
        """
        self.llm_client = client
        print(f"LLM client set: {type(client).__name__}")
    
    def create_agent(self, 
                     name: str,
                     personality: str = "",
                     system_prompt: str = "",
                     model: str = "gpt-3.5-turbo",
                     temperature: float = 0.7,
                     max_tokens: int = 500) -> Agent:
        """
        Create a new AI agent.
        
        Args:
            name: Agent's name
            personality: Personality description
            system_prompt: System prompt for the agent
            model: LLM model to use
            temperature: Response temperature
            max_tokens: Maximum tokens in response
            
        Returns:
            Created agent
        """
        if name in self.agents:
            raise ValueError(f"Agent '{name}' already exists")
        
        config = AgentConfig(
            name=name,
            personality=personality,
            system_prompt=system_prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        agent = Agent(config, storage=self.storage)
        self.agents[name] = agent
        
        # Save configuration
        self._save_agents_config()
        
        print(f"Agent '{name}' created successfully")
        return agent
    
    def get_agent(self, name: str) -> Optional[Agent]:
        """
        Get an agent by name.
        
        Args:
            name: Agent's name
            
        Returns:
            Agent or None if not found
        """
        return self.agents.get(name)
    
    def list_agents(self) -> List[str]:
        """
        List all agent names.
        
        Returns:
            List of agent names
        """
        return list(self.agents.keys())
    
    def delete_agent(self, name: str):
        """
        Delete an agent.
        
        Note: This only removes the agent from the manager,
        it does not delete Google Drive files.
        
        Args:
            name: Agent's name
        """
        if name in self.agents:
            del self.agents[name]
            self._save_agents_config()
            print(f"Agent '{name}' deleted from manager")
        else:
            raise ValueError(f"Agent '{name}' not found")
    
    def chat_with_agent(self, agent_name: str, user_input: str) -> str:
        """
        Chat with a specific agent.
        
        Args:
            agent_name: Name of the agent to chat with
            user_input: User's message
            
        Returns:
            Agent's response
        """
        agent = self.get_agent(agent_name)
        if not agent:
            raise ValueError(f"Agent '{agent_name}' not found")
        
        return agent.process_interaction(user_input, self.llm_client)
    
    def get_agent_summary(self, agent_name: str) -> Dict[str, Any]:
        """
        Get summary information about an agent.
        
        Args:
            agent_name: Agent's name
            
        Returns:
            Agent summary dictionary
        """
        agent = self.get_agent(agent_name)
        if not agent:
            raise ValueError(f"Agent '{agent_name}' not found")
        
        return agent.get_summary()
    
    def add_agent_trait(self, agent_name: str, trait: str, value: str, notes: str = ""):
        """
        Add a character trait to an agent.
        
        Args:
            agent_name: Agent's name
            trait: Trait name
            value: Trait value
            notes: Optional notes
        """
        agent = self.get_agent(agent_name)
        if not agent:
            raise ValueError(f"Agent '{agent_name}' not found")
        
        agent.add_character_trait(trait, value, notes)
        print(f"Trait '{trait}' added to agent '{agent_name}'")
    
    def _load_agents_config(self):
        """Load agents from configuration file."""
        if not os.path.exists(self.config_file):
            print(f"No existing configuration found at {self.config_file}")
            return
        
        try:
            with open(self.config_file, 'r') as f:
                config_data = json.load(f)
            
            for agent_data in config_data.get('agents', []):
                agent = Agent.from_dict(agent_data, storage=self.storage)
                self.agents[agent.config.name] = agent
            
            print(f"Loaded {len(self.agents)} agents from configuration")
        except Exception as e:
            print(f"Error loading agents config: {e}")
    
    def _save_agents_config(self):
        """Save agents to configuration file."""
        config_data = {
            'agents': [agent.to_dict() for agent in self.agents.values()]
        }
        
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config_data, f, indent=2)
            print(f"Configuration saved to {self.config_file}")
        except Exception as e:
            print(f"Error saving agents config: {e}")
    
    def get_all_summaries(self) -> Dict[str, Dict[str, Any]]:
        """
        Get summaries for all agents.
        
        Returns:
            Dictionary mapping agent names to their summaries
        """
        return {
            name: agent.get_summary()
            for name, agent in self.agents.items()
        }
    
    def export_agent(self, agent_name: str, output_path: str):
        """
        Export an agent's configuration to a file.
        
        Args:
            agent_name: Agent's name
            output_path: Path to save the export
        """
        agent = self.get_agent(agent_name)
        if not agent:
            raise ValueError(f"Agent '{agent_name}' not found")
        
        with open(output_path, 'w') as f:
            json.dump(agent.to_dict(), f, indent=2)
        
        print(f"Agent '{agent_name}' exported to {output_path}")
    
    def import_agent(self, import_path: str) -> Agent:
        """
        Import an agent from a file.
        
        Args:
            import_path: Path to the import file
            
        Returns:
            Imported agent
        """
        with open(import_path, 'r') as f:
            agent_data = json.load(f)
        
        agent = Agent.from_dict(agent_data, storage=self.storage)
        
        if agent.config.name in self.agents:
            raise ValueError(f"Agent '{agent.config.name}' already exists")
        
        self.agents[agent.config.name] = agent
        self._save_agents_config()
        
        print(f"Agent '{agent.config.name}' imported successfully")
        return agent
