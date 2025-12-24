"""
SynthChat - A Silly Tavern style LLM manager for multiple agents.

This package provides a multi-agent LLM system with Google Drive integration
for persistent memory and character development.
"""

__version__ = "0.1.0"

from synthchat.agent import Agent
from synthchat.agent_manager import AgentManager

__all__ = ["Agent", "AgentManager"]
