"""
Basic tests for SynthChat functionality.

These tests verify the core functionality without requiring Google Drive credentials.
"""

import unittest
import json
import tempfile
import os
from pathlib import Path

from synthchat.agent import Agent, AgentConfig, Interaction
from synthchat.agent_manager import AgentManager


class TestAgentConfig(unittest.TestCase):
    """Test AgentConfig model."""
    
    def test_agent_config_creation(self):
        """Test creating an agent configuration."""
        config = AgentConfig(
            name="TestAgent",
            personality="friendly",
            system_prompt="You are a test agent"
        )
        
        self.assertEqual(config.name, "TestAgent")
        self.assertEqual(config.personality, "friendly")
        self.assertEqual(config.system_prompt, "You are a test agent")
        self.assertEqual(config.model, "gpt-3.5-turbo")  # default
        self.assertEqual(config.temperature, 0.7)  # default


class TestAgent(unittest.TestCase):
    """Test Agent class."""
    
    def setUp(self):
        """Set up test agent."""
        self.config = AgentConfig(
            name="TestAgent",
            personality="a helpful test agent",
            system_prompt="You are a test agent"
        )
        self.agent = Agent(self.config, storage=None)
    
    def test_agent_creation(self):
        """Test agent creation."""
        self.assertEqual(self.agent.config.name, "TestAgent")
        self.assertEqual(len(self.agent.interaction_history), 0)
        self.assertEqual(len(self.agent.character_traits), 0)
    
    def test_fallback_response(self):
        """Test agent fallback response without LLM."""
        response = self.agent.process_interaction("Hello!")
        self.assertIn("TestAgent", response)
        self.assertIn("Hello!", response)
    
    def test_interaction_history(self):
        """Test interaction history is recorded."""
        self.agent.process_interaction("Test message 1")
        self.agent.process_interaction("Test message 2")
        
        self.assertEqual(len(self.agent.interaction_history), 2)
        self.assertEqual(self.agent.interaction_history[0].user_input, "Test message 1")
        self.assertEqual(self.agent.interaction_history[1].user_input, "Test message 2")
    
    def test_character_traits(self):
        """Test adding character traits."""
        self.agent.add_character_trait("knowledge", "high", "Test note")
        
        self.assertIn("knowledge", self.agent.character_traits)
        self.assertEqual(self.agent.character_traits["knowledge"]["value"], "high")
        self.assertEqual(self.agent.character_traits["knowledge"]["notes"], "Test note")
    
    def test_agent_summary(self):
        """Test getting agent summary."""
        self.agent.process_interaction("Test")
        self.agent.add_character_trait("test_trait", "test_value")
        
        summary = self.agent.get_summary()
        
        self.assertEqual(summary["name"], "TestAgent")
        self.assertEqual(summary["total_interactions"], 1)
        self.assertIn("test_trait", summary["character_traits"])
    
    def test_agent_serialization(self):
        """Test agent to_dict and from_dict."""
        self.agent.add_character_trait("trait1", "value1")
        self.agent.process_interaction("Test")
        
        # Convert to dict
        agent_dict = self.agent.to_dict()
        
        # Verify dict structure
        self.assertIn("config", agent_dict)
        self.assertIn("character_traits", agent_dict)
        self.assertEqual(agent_dict["interaction_count"], 1)
        
        # Recreate from dict
        new_agent = Agent.from_dict(agent_dict, storage=None)
        
        self.assertEqual(new_agent.config.name, "TestAgent")
        self.assertIn("trait1", new_agent.character_traits)


class TestAgentManager(unittest.TestCase):
    """Test AgentManager class."""
    
    def setUp(self):
        """Set up test manager with temporary config file."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_file = os.path.join(self.temp_dir, "test_config.json")
        
        # Create manager without Google Drive (no credentials)
        self.manager = AgentManager(
            credentials_path="/nonexistent/credentials.json",
            config_file=self.config_file
        )
    
    def tearDown(self):
        """Clean up temporary files."""
        if os.path.exists(self.config_file):
            os.remove(self.config_file)
        os.rmdir(self.temp_dir)
    
    def test_manager_creation(self):
        """Test manager creation."""
        self.assertIsNotNone(self.manager)
        self.assertEqual(len(self.manager.agents), 0)
    
    def test_create_agent(self):
        """Test creating an agent through manager."""
        agent = self.manager.create_agent(
            name="TestAgent",
            personality="friendly"
        )
        
        self.assertIsNotNone(agent)
        self.assertEqual(agent.config.name, "TestAgent")
        self.assertIn("TestAgent", self.manager.list_agents())
    
    def test_duplicate_agent_error(self):
        """Test that creating duplicate agent raises error."""
        self.manager.create_agent(name="Agent1")
        
        with self.assertRaises(ValueError):
            self.manager.create_agent(name="Agent1")
    
    def test_get_agent(self):
        """Test getting an agent by name."""
        self.manager.create_agent(name="Agent1")
        
        agent = self.manager.get_agent("Agent1")
        self.assertIsNotNone(agent)
        self.assertEqual(agent.config.name, "Agent1")
        
        # Test non-existent agent
        agent = self.manager.get_agent("NonExistent")
        self.assertIsNone(agent)
    
    def test_list_agents(self):
        """Test listing all agents."""
        self.manager.create_agent(name="Agent1")
        self.manager.create_agent(name="Agent2")
        self.manager.create_agent(name="Agent3")
        
        agents = self.manager.list_agents()
        self.assertEqual(len(agents), 3)
        self.assertIn("Agent1", agents)
        self.assertIn("Agent2", agents)
        self.assertIn("Agent3", agents)
    
    def test_delete_agent(self):
        """Test deleting an agent."""
        self.manager.create_agent(name="Agent1")
        self.assertEqual(len(self.manager.list_agents()), 1)
        
        self.manager.delete_agent("Agent1")
        self.assertEqual(len(self.manager.list_agents()), 0)
    
    def test_chat_with_agent(self):
        """Test chatting with an agent through manager."""
        self.manager.create_agent(name="Agent1")
        
        response = self.manager.chat_with_agent("Agent1", "Hello!")
        self.assertIsNotNone(response)
        self.assertIn("Agent1", response)
    
    def test_add_agent_trait(self):
        """Test adding trait to agent through manager."""
        self.manager.create_agent(name="Agent1")
        self.manager.add_agent_trait("Agent1", "knowledge", "high")
        
        agent = self.manager.get_agent("Agent1")
        self.assertIn("knowledge", agent.character_traits)
    
    def test_config_persistence(self):
        """Test that configuration is saved and loaded."""
        # Create agents
        self.manager.create_agent(name="Agent1", personality="friendly")
        self.manager.create_agent(name="Agent2", personality="serious")
        
        # Create new manager with same config file
        new_manager = AgentManager(
            credentials_path="/nonexistent/credentials.json",
            config_file=self.config_file
        )
        
        # Check agents were loaded
        agents = new_manager.list_agents()
        self.assertEqual(len(agents), 2)
        self.assertIn("Agent1", agents)
        self.assertIn("Agent2", agents)
        
        # Check personality preserved
        agent1 = new_manager.get_agent("Agent1")
        self.assertEqual(agent1.config.personality, "friendly")
    
    def test_export_import_agent(self):
        """Test exporting and importing agents."""
        # Create agent
        self.manager.create_agent(name="Agent1", personality="test")
        self.manager.add_agent_trait("Agent1", "trait1", "value1")
        
        # Export
        export_path = os.path.join(self.temp_dir, "export.json")
        self.manager.export_agent("Agent1", export_path)
        
        self.assertTrue(os.path.exists(export_path))
        
        # Delete agent
        self.manager.delete_agent("Agent1")
        self.assertEqual(len(self.manager.list_agents()), 0)
        
        # Import
        self.manager.import_agent(export_path)
        
        # Verify
        agent = self.manager.get_agent("Agent1")
        self.assertIsNotNone(agent)
        self.assertEqual(agent.config.personality, "test")
        self.assertIn("trait1", agent.character_traits)
        
        # Cleanup
        os.remove(export_path)
    
    def test_get_all_summaries(self):
        """Test getting summaries for all agents."""
        self.manager.create_agent(name="Agent1")
        self.manager.create_agent(name="Agent2")
        
        summaries = self.manager.get_all_summaries()
        
        self.assertEqual(len(summaries), 2)
        self.assertIn("Agent1", summaries)
        self.assertIn("Agent2", summaries)


class TestInteraction(unittest.TestCase):
    """Test Interaction model."""
    
    def test_interaction_creation(self):
        """Test creating an interaction."""
        interaction = Interaction(
            user_input="Hello",
            agent_response="Hi there!",
            thought_pattern="User is greeting",
            emotion="friendly"
        )
        
        self.assertEqual(interaction.user_input, "Hello")
        self.assertEqual(interaction.agent_response, "Hi there!")
        self.assertEqual(interaction.thought_pattern, "User is greeting")
        self.assertEqual(interaction.emotion, "friendly")
        self.assertIsNotNone(interaction.timestamp)


if __name__ == '__main__':
    unittest.main()
