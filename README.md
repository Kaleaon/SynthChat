# SynthChat

A Silly Tavern-style multi-agent LLM manager for Android, built with Flutter.

## Features

- 🤖 **Multiple AI Characters**: Create and manage multiple AI characters, each with unique personalities
- 🎨 **Beautiful Dark Theme**: Silly Tavern-inspired chat UI with character cards and chat bubbles
- 🔐 **Secure Authentication**: Login with local accounts or Bluesky (AT Protocol)
- 🖼️ **Avatar Support**: Upload custom avatars or use generated initials
- 💬 **Chat Interface**: Beautiful message bubbles with emotions and typing indicators
- 🧠 **Personality Evolution**: Characters develop and change over time
- 😊 **Mood Tracking**: Real-time mood visualization with emoji indicators
- 🏠 **Collaborative Rooms**: Create rooms for multi-user character interactions
- 📄 **Document Import**: Create characters from markdown, text, or JSON files
- 🌿 **Memory Branching**: Fork conversations for private interactions

## Quick Start

### Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio or VS Code with Flutter extensions
- An Android device or emulator

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Kaleaon/SynthChat.git
cd SynthChat/flutter_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run on a connected device or emulator:
```bash
flutter run
```

### Building APK

For a release APK:
```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

## Features Overview

### Core Features (V1)
- **Character Cards**: Grid of character cards with avatars
- **Chat Bubbles**: Beautiful message bubbles with emotions
- **Local Storage**: SQLite database for offline access
- **Secure Auth**: Password hashing with PBKDF2 (100,000 iterations, per-user salt)
- **Dark Theme**: Silly Tavern-inspired purple/dark blue theme
- **LLM Settings**: Configure model, temperature, and max tokens

### V2: Room Sharing & Collaborative Interactions
- Create public or private rooms for group conversations
- Add multiple characters to a room
- Invite users by username or email
- Room participant management

### V3: Memory Branching & Forking
- Fork conversations for private memory branches
- Maintain separate memory contexts
- Merge branches back to share memories with main context
- Branch hierarchy visualization

### V4: AI-Powered Document Parsing
- Import character definitions from documents (.md, .txt, .json, .html)
- AI extraction of character traits, personality, and backstory
- Automatic system prompt generation
- Character creation from parsed data

### V5: Personality Evolution & Mood Tracking
- Real-time mood tracking with emoji visualization
- Trait evolution based on conversation analysis
- Internal reasoning/thought pattern display
- Personality event history
- Automatic mood and trait changes from interactions

### Bluesky AT Protocol Integration
- Federated login using the AT Protocol
- Use your Bluesky handle (e.g., user.bsky.social)
- App Password authentication for security
- Link existing accounts to Bluesky

## Project Structure

```
SynthChat/
├── flutter_app/                 # Android Application (Flutter)
│   ├── lib/
│   │   ├── main.dart            # App entry point
│   │   ├── models/              # Data models
│   │   │   ├── character.dart
│   │   │   ├── message.dart
│   │   │   └── user.dart
│   │   ├── services/            # Business logic
│   │   │   ├── auth_service.dart
│   │   │   ├── bluesky_auth_service.dart
│   │   │   ├── character_service.dart
│   │   │   ├── chat_service.dart
│   │   │   ├── database_service.dart
│   │   │   ├── document_parser_service.dart
│   │   │   ├── memory_branch_service.dart
│   │   │   ├── personality_evolution_service.dart
│   │   │   └── room_service.dart
│   │   ├── screens/             # UI screens
│   │   ├── widgets/             # Reusable widgets
│   │   └── theme/               # App theming
│   ├── pubspec.yaml             # Flutter dependencies
│   └── README.md                # Detailed app documentation
├── LICENSE
└── README.md                    # This file
```

## Configuration

### OpenAI API Key

To enable AI responses, you'll need to configure your OpenAI API key in the app settings or modify the `ChatService` to read from secure storage.

### Character Configuration

Each character can be configured with:
- `name`: Character's name
- `description`: Brief description
- `personality`: Personality traits and behavior
- `system_prompt`: System prompt for LLM
- `greeting`: First message when starting a conversation
- `model`: LLM model to use (default: `gpt-3.5-turbo`)
- `temperature`: Response creativity (0.0-1.0)
- `max_tokens`: Maximum response length

## Security Features

- **PBKDF2 Password Hashing**: Secure password storage with 100,000 iterations
- **Per-User Salt**: Unique 32-byte cryptographic salt for each user
- **32-byte Key Length**: Strong hash output
- **Constant-Time Comparison**: Protection against timing attacks
- **Database Transactions**: Atomic operations for data integrity
- **Synchronized Initialization**: Thread-safe database setup

## Troubleshooting

### LLM Provider Issues

If you're not getting proper responses:
1. Check your OpenAI API key is set correctly
2. Verify the model name is valid
3. Check your API quota/credits
4. Ensure you have internet connectivity

### App Crashes

1. Clear app data and restart
2. Check for Flutter/Dart version compatibility
3. Ensure all dependencies are installed (`flutter pub get`)

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

See LICENSE file for details.

## Acknowledgments

Inspired by [Silly Tavern](https://github.com/SillyTavern/SillyTavern), this project provides a native Android experience for multi-character AI chat.
