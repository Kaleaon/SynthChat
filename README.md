# SynthChat

A Silly Tavern-style multi-agent LLM manager with Google Drive integration for persistent memory and character development.

## Features

- 🤖 **Multiple AI Agents**: Create and manage multiple AI agents, each with unique personalities and configurations
- 💾 **Google Drive Integration**: Each agent gets their own Google Drive folder with:
  - Memory document for interactions
  - Private thoughts document
  - Character development spreadsheet
- 🧠 **Persistent Memory**: All interactions are automatically saved to Google Drive
- 💭 **Thought Patterns**: Agents maintain internal thought processes that are logged separately
- 📊 **Character Development Tracking**: Track character traits and evolution over time
- 🔌 **LLM Provider Agnostic**: Works with OpenAI and compatible APIs

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Kaleaon/SynthChat.git
cd SynthChat
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env and add your API keys
```

## Google Drive Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Drive API and Google Sheets API
4. Create OAuth 2.0 credentials (Desktop application)
5. Download the credentials and save as `credentials.json` in the project root
6. On first run, you'll be prompted to authorize the application

## Quick Start

### Run the Example Script

```bash
python example.py
```

This will:
- Create three example agents (Alice, Bob, and Carol)
- Demonstrate interactions with each agent
- Show how memories are saved to Google Drive
- Display agent summaries

### Interactive Chat

```bash
python interactive_chat.py
```

This launches an interactive chat interface where you can:
- Select which agent to chat with
- Have conversations that are automatically saved
- Add character traits
- View agent summaries

## Usage

### Basic Usage

```python
from synthchat import AgentManager
from openai import OpenAI

# Initialize the manager
manager = AgentManager(
    credentials_path="credentials.json",
    token_path="token.json"
)

# Set up LLM client (optional, but recommended)
client = OpenAI(api_key="your-api-key")
manager.set_llm_client(client)

# Create an agent
agent = manager.create_agent(
    name="Alice",
    personality="a helpful and friendly AI assistant",
    system_prompt="You are Alice, a friendly assistant.",
    temperature=0.7
)

# Chat with the agent
response = manager.chat_with_agent("Alice", "Hello! How are you?")
print(response)

# Add a character trait
manager.add_agent_trait("Alice", "expertise", "Python programming")

# Get agent summary
summary = manager.get_agent_summary("Alice")
print(summary)
```

### Advanced Features

#### Export/Import Agents

```python
# Export an agent to a file
manager.export_agent("Alice", "alice_backup.json")

# Import an agent from a file
manager.import_agent("alice_backup.json")
```

#### Multiple Agents

```python
# Create multiple agents with different personalities
manager.create_agent(
    name="Bob",
    personality="a creative storyteller",
    temperature=0.9
)

manager.create_agent(
    name="Carol",
    personality="a technical expert",
    temperature=0.5
)

# List all agents
agents = manager.list_agents()
print(agents)  # ['Alice', 'Bob', 'Carol']

# Get summaries for all agents
summaries = manager.get_all_summaries()
```

## Project Structure

```
SynthChat/
├── synthchat/
│   ├── __init__.py              # Package initialization
│   ├── agent.py                 # Agent class with memory and personality
│   ├── agent_manager.py         # Manages multiple agents
│   └── google_drive_storage.py  # Google Drive integration
├── example.py                   # Example usage script
├── interactive_chat.py          # Interactive chat interface
├── requirements.txt             # Python dependencies
├── .env.example                 # Environment variables template
└── README.md                    # This file
```

## How It Works

### Agent Memory Storage

Each agent gets its own Google Drive folder containing:

1. **Memory Document**: Stores all interactions and conversations
2. **Thoughts Document**: Private thought patterns and internal reasoning
3. **Character Development Sheet**: Spreadsheet tracking:
   - Interactions (timestamp, user input, response, thoughts, emotion, context)
   - Character Traits (trait name, value, last updated, notes)
   - Memory Snapshots (periodic state saves)

### Interaction Flow

1. User sends a message to an agent
2. Agent generates internal thought pattern
3. Agent processes the message using LLM (if configured)
4. Response is generated and returned
5. Interaction is saved to:
   - Local memory
   - Google Drive spreadsheet (Interactions sheet)
   - Thoughts logged to thoughts document

### Character Development

Agents can develop over time through:
- Accumulating interaction history
- Tracking character traits
- Maintaining context across conversations
- Storing emotional states and thought patterns

## Configuration

### Environment Variables

- `GOOGLE_CREDENTIALS_PATH`: Path to Google API credentials (default: `credentials.json`)
- `GOOGLE_TOKEN_PATH`: Path to token file (default: `token.json`)
- `OPENAI_API_KEY`: Your OpenAI API key (optional)
- `AGENT_MEMORY_FOLDER_ID`: Parent folder ID in Google Drive (optional)

### Agent Configuration

Each agent can be configured with:
- `name`: Unique identifier
- `personality`: Personality description
- `system_prompt`: System prompt for LLM
- `model`: LLM model to use (default: `gpt-3.5-turbo`)
- `temperature`: Response creativity (0.0-1.0)
- `max_tokens`: Maximum response length

## Examples

### Creating a Character with Specific Traits

```python
# Create a character
manager.create_agent(
    name="Sherlock",
    personality="a brilliant detective with exceptional observation skills",
    system_prompt="You are Sherlock Holmes, the famous detective. You're analytical, observant, and deduce facts from small details.",
    temperature=0.6
)

# Add character traits
manager.add_agent_trait("Sherlock", "observation", "exceptional", "Notices minute details")
manager.add_agent_trait("Sherlock", "deduction", "masterful", "Expert at logical reasoning")
manager.add_agent_trait("Sherlock", "knowledge", "encyclopedic", "Vast knowledge base")

# Interact
response = manager.chat_with_agent("Sherlock", "I noticed some mud on the carpet.")
```

### Group Conversations

```python
# Create multiple agents
agents = ["Alice", "Bob", "Carol"]

# Simulate a group discussion
topic = "What is the future of AI?"

for agent_name in agents:
    response = manager.chat_with_agent(agent_name, topic)
    print(f"{agent_name}: {response}\n")
```

## Troubleshooting

### Google Drive Authentication Issues

If you encounter authentication errors:
1. Delete `token.json`
2. Run the script again
3. Complete the OAuth flow in your browser

### LLM Provider Issues

If you're not getting proper responses:
1. Check your API key is set correctly
2. Verify the model name is valid
3. Check your API quota/credits
4. Review the LLM client configuration

### Storage Issues

If interactions aren't being saved:
1. Verify Google Drive credentials are valid
2. Check internet connection
3. Review Google Drive API quotas
4. Check file permissions in Google Drive

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

See LICENSE file for details.

## Acknowledgments

Inspired by [Silly Tavern](https://github.com/SillyTavern/SillyTavern), this project aims to provide a lightweight, Python-based alternative with cloud storage integration.
