"""
Agent class representing an individual AI character with memory and personality.
"""

from typing import Optional, Dict, Any, List
from datetime import datetime
import json
from pydantic import BaseModel, Field


class AgentConfig(BaseModel):
    """Configuration for an AI agent."""
    name: str = Field(..., description="Agent's name")
    personality: str = Field(default="", description="Agent's personality description")
    system_prompt: str = Field(default="", description="System prompt for the agent")
    model: str = Field(default="gpt-3.5-turbo", description="LLM model to use")
    temperature: float = Field(default=0.7, description="Temperature for responses")
    max_tokens: int = Field(default=500, description="Maximum tokens in response")


class Interaction(BaseModel):
    """Represents a single interaction with the agent."""
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    user_input: str
    agent_response: str
    thought_pattern: str = Field(default="", description="Internal thought process")
    emotion: str = Field(default="neutral", description="Agent's emotional state")
    context: str = Field(default="", description="Additional context")


class Agent:
    """
    Represents an AI agent with persistent memory and character development.
    
    Each agent has their own:
    - Google Drive folder
    - Memory document
    - Private thoughts document
    - Character development spreadsheet
    """
    
    def __init__(self, config: AgentConfig, storage=None):
        """
        Initialize an agent.
        
        Args:
            config: Agent configuration
            storage: GoogleDriveStorage instance (optional)
        """
        self.config = config
        self.storage = storage
        self.drive_files: Optional[Dict[str, str]] = None
        self.interaction_history: List[Interaction] = []
        self.character_traits: Dict[str, Any] = {}
        
        # Initialize Google Drive files if storage is provided
        if self.storage:
            self._initialize_storage()
    
    def _initialize_storage(self):
        """Initialize Google Drive storage for this agent."""
        if not self.storage:
            return
        
        self.drive_files = self.storage.get_or_create_agent_files(self.config.name)
        print(f"Agent '{self.config.name}' storage initialized:")
        print(f"  Folder ID: {self.drive_files['folder_id']}")
        print(f"  Memory Doc ID: {self.drive_files['memory_doc_id']}")
        print(f"  Thoughts Doc ID: {self.drive_files['thoughts_doc_id']}")
        print(f"  Character Sheet ID: {self.drive_files['sheet_id']}")
    
    def process_interaction(self, user_input: str, llm_client=None) -> str:
        """
        Process a user interaction and generate a response.
        
        Args:
            user_input: The user's input message
            llm_client: Optional LLM client for generating responses
            
        Returns:
            Agent's response
        """
        # Generate thought pattern (internal reasoning)
        thought_pattern = self._generate_thought_pattern(user_input)
        
        # Generate response
        if llm_client:
            agent_response = self._generate_llm_response(user_input, thought_pattern, llm_client)
        else:
            # Fallback response if no LLM client provided
            agent_response = self._generate_fallback_response(user_input)
        
        # Determine emotion based on context
        emotion = self._determine_emotion(user_input, agent_response)
        
        # Create interaction record
        interaction = Interaction(
            user_input=user_input,
            agent_response=agent_response,
            thought_pattern=thought_pattern,
            emotion=emotion,
            context=self._build_context()
        )
        
        # Store interaction
        self.interaction_history.append(interaction)
        
        # Save to Google Drive if storage is available
        if self.storage and self.drive_files:
            self._save_interaction(interaction)
        
        return agent_response
    
    def _generate_thought_pattern(self, user_input: str) -> str:
        """
        Generate internal thought pattern for the agent.
        This represents the agent's private reasoning process.
        
        Args:
            user_input: User's input
            
        Returns:
            Thought pattern description
        """
        # Simple thought pattern generation
        # In a real system, this would use an LLM with a specific prompt
        thoughts = []
        
        if "?" in user_input:
            thoughts.append("The user is asking a question")
        if len(user_input.split()) > 20:
            thoughts.append("This is a detailed message requiring careful consideration")
        
        # Check interaction history for context
        if len(self.interaction_history) > 0:
            thoughts.append(f"Building on our previous {len(self.interaction_history)} interactions")
        
        return " | ".join(thoughts) if thoughts else "Processing new input"
    
    def _generate_llm_response(self, user_input: str, thought_pattern: str, llm_client) -> str:
        """
        Generate response using LLM.
        
        Args:
            user_input: User's input
            thought_pattern: Agent's internal thoughts
            llm_client: LLM client instance
            
        Returns:
            Generated response
        """
        # Build context from recent interactions
        context_messages = []
        
        # Add system prompt
        system_prompt = self.config.system_prompt or f"You are {self.config.name}, {self.config.personality}"
        context_messages.append({
            "role": "system",
            "content": system_prompt
        })
        
        # Add recent conversation history (last 5 interactions)
        for interaction in self.interaction_history[-5:]:
            context_messages.append({
                "role": "user",
                "content": interaction.user_input
            })
            context_messages.append({
                "role": "assistant",
                "content": interaction.agent_response
            })
        
        # Add current message
        context_messages.append({
            "role": "user",
            "content": user_input
        })
        
        # Call LLM (OpenAI-style API)
        try:
            response = llm_client.chat.completions.create(
                model=self.config.model,
                messages=context_messages,
                temperature=self.config.temperature,
                max_tokens=self.config.max_tokens
            )
            return response.choices[0].message.content
        except Exception as e:
            print(f"Error calling LLM: {e}")
            return self._generate_fallback_response(user_input)
    
    def _generate_fallback_response(self, user_input: str) -> str:
        """
        Generate a simple fallback response when LLM is not available.
        
        Args:
            user_input: User's input
            
        Returns:
            Fallback response
        """
        return f"{self.config.name}: I understand you said '{user_input[:50]}...'. " \
               f"(Note: LLM client not configured for full response)"
    
    def _determine_emotion(self, user_input: str, agent_response: str) -> str:
        """
        Determine the agent's emotional state based on the interaction.
        
        Args:
            user_input: User's input
            agent_response: Agent's response
            
        Returns:
            Emotion label
        """
        # Simple emotion detection based on keywords
        # In a real system, this would use sentiment analysis
        user_lower = user_input.lower()
        
        if any(word in user_lower for word in ["happy", "great", "excellent", "wonderful"]):
            return "happy"
        elif any(word in user_lower for word in ["sad", "upset", "angry", "frustrated"]):
            return "empathetic"
        elif "?" in user_input:
            return "curious"
        else:
            return "neutral"
    
    def _build_context(self) -> str:
        """
        Build context string from current state.
        
        Returns:
            Context string
        """
        context_parts = [
            f"Interaction #{len(self.interaction_history) + 1}",
            f"Character traits: {len(self.character_traits)}"
        ]
        return " | ".join(context_parts)
    
    def _save_interaction(self, interaction: Interaction):
        """
        Save interaction to Google Drive.
        
        Args:
            interaction: Interaction to save
        """
        if not self.storage or not self.drive_files:
            return
        
        # Append to spreadsheet
        interaction_data = {
            'timestamp': interaction.timestamp,
            'user_input': interaction.user_input,
            'agent_response': interaction.agent_response,
            'thought_pattern': interaction.thought_pattern,
            'emotion': interaction.emotion,
            'context': interaction.context
        }
        
        self.storage.append_interaction(
            self.drive_files['sheet_id'],
            interaction_data
        )
        
        # Save private thoughts to thoughts document
        if interaction.thought_pattern:
            thought_entry = f"\n[{interaction.timestamp}] {interaction.thought_pattern}"
            # In a full implementation, this would append to the Google Doc
            # For now, we'll just log it
            print(f"Private thought logged: {thought_entry}")
    
    def add_character_trait(self, trait: str, value: str, notes: str = ""):
        """
        Add or update a character trait.
        
        Args:
            trait: Trait name
            value: Trait value
            notes: Optional notes
        """
        self.character_traits[trait] = {
            'value': value,
            'notes': notes,
            'updated': datetime.now().isoformat()
        }
        
        # Save to Google Drive
        if self.storage and self.drive_files:
            self.storage.update_character_trait(
                self.drive_files['sheet_id'],
                trait,
                value,
                notes
            )
    
    def get_summary(self) -> Dict[str, Any]:
        """
        Get a summary of the agent's current state.
        
        Returns:
            Dictionary with agent summary
        """
        return {
            'name': self.config.name,
            'personality': self.config.personality,
            'total_interactions': len(self.interaction_history),
            'character_traits': list(self.character_traits.keys()),
            'drive_files': self.drive_files
        }
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert agent to dictionary for serialization.
        
        Returns:
            Dictionary representation
        """
        return {
            'config': self.config.model_dump(),
            'character_traits': self.character_traits,
            'interaction_count': len(self.interaction_history),
            'drive_files': self.drive_files
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any], storage=None) -> 'Agent':
        """
        Create agent from dictionary.
        
        Args:
            data: Dictionary representation
            storage: GoogleDriveStorage instance
            
        Returns:
            Agent instance
        """
        config = AgentConfig(**data['config'])
        agent = cls(config, storage)
        agent.character_traits = data.get('character_traits', {})
        agent.drive_files = data.get('drive_files')
        return agent
