# SynthChat - Flutter Android App

A Silly Tavern-style multi-agent LLM manager for Android with local storage and OpenAI integration.

## Features

### Core Features (V1)
- 🤖 **Multiple AI Characters**: Create and manage unique AI personalities
- 💬 **Chat Interface**: Beautiful chat bubbles with message history
- 🎨 **Dark Theme**: Silly Tavern-inspired dark UI
- 🔐 **Secure Authentication**: PBKDF2 password hashing with 100,000 iterations
- 🦋 **Bluesky Login**: Federated authentication via AT Protocol
- 💾 **Local Storage**: SQLite database for offline access
- 🧠 **Thought Patterns**: Characters maintain internal reasoning
- 😊 **Emotion Tracking**: Messages display character emotions
- ⚙️ **Customizable LLM**: Configure model, temperature, and tokens

### V2: Room Sharing & Collaboration
- 👥 **Collaborative Rooms**: Create public or private rooms for group interactions
- 🔗 **Multi-Character Rooms**: Add multiple characters to the same room
- 👤 **Participant Management**: Track who's in each room
- 📧 **User Invitations**: Invite other users to your chatrooms by username or email
- 📬 **Invitation Management**: Accept/decline pending invitations with custom messages

### V3: Memory Branching
- 🌿 **Memory Forking**: Create private conversation branches
- 🔀 **Branch Merging**: Share memories back to the main context
- 📊 **Branch Hierarchy**: Visualize memory branch relationships

### V4: Document Import
- 📄 **Document Parsing**: Import characters from .md, .txt, .json, .html files
- 🤖 **AI Extraction**: Automatic character trait and personality extraction
- ✨ **Auto-Generation**: System prompts generated from parsed data

### V5: Personality Evolution
- 🌡️ **Mood Tracking**: Real-time mood state with emoji visualization
- 📈 **Trait Evolution**: Automatic trait changes from conversation analysis
- 💭 **Internal Reasoning**: View character's thought patterns
- 📜 **Evolution History**: Track personality changes over time

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or higher
- Android Studio or VS Code with Flutter extensions
- An Android device or emulator

### Installation

1. Navigate to the flutter_app directory:
```bash
cd flutter_app
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

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                         # App entry point
│   ├── models/                           # Data models
│   │   ├── user.dart
│   │   ├── character.dart
│   │   └── message.dart
│   ├── services/                         # Business logic
    │   │   ├── database_service.dart         # SQLite with PBKDF2 auth
    │   │   ├── auth_service.dart             # Local + Bluesky auth
    │   │   ├── bluesky_auth_service.dart     # AT Protocol authentication
    │   │   ├── character_service.dart
    │   │   ├── chat_service.dart
    │   │   ├── room_service.dart             # V2: Room + invitations
    │   │   ├── memory_branch_service.dart    # V3: Memory forking
    │   │   ├── document_parser_service.dart  # V4: Document import
    │   │   └── personality_evolution_service.dart  # V5: Personality tracking
│   ├── screens/                          # UI screens
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── characters_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── character_edit_screen.dart
│   │   ├── rooms_screen.dart             # V2: Room UI
│   │   ├── document_import_screen.dart   # V4: Document import UI
│   │   └── personality_screen.dart       # V5: Personality view
│   ├── widgets/                          # Reusable widgets
│   │   ├── character_card.dart
│   │   └── message_bubble.dart
│   └── theme/                            # App theming
│       └── app_theme.dart
├── assets/                               # Static assets
│   └── avatars/
├── pubspec.yaml                          # Dependencies
└── README.md
```

## Configuration

### OpenAI API Key

To enable full LLM responses, set your OpenAI API key. Currently, the app uses a fallback response when no API key is configured.

You can add API key configuration in the settings or modify the `ChatService` to read from environment variables or secure storage.

## Screenshots

The app features:
- **Login/Register**: Clean authentication screens
- **Characters List**: Grid of character cards
- **Chat Interface**: Message bubbles with typing indicators
- **Character Editor**: Full customization of AI characters

## Customization

### Adding New Models

Edit the `_models` list in `character_edit_screen.dart`:

```dart
final List<String> _models = [
  'gpt-3.5-turbo',
  'gpt-4',
  'gpt-4-turbo',
  'your-custom-model',
];
```

### Changing Theme Colors

Edit `lib/theme/app_theme.dart` to customize the color palette.

## Dependencies

- `provider` - State management
- `sqflite` - Local SQLite database
- `shared_preferences` - Simple key-value storage
- `http` - HTTP client for API calls
- `crypto` - Secure PBKDF2 password hashing
- `intl` - Date formatting
- `file_picker` - Document import (V4)

## Security

### Password Hashing
- **Algorithm**: PBKDF2 with HMAC-SHA256
- **Iterations**: 100,000 (industry standard)
- **Salt**: 32-byte cryptographically random per-user salt
- **Key Length**: 32 bytes
- **Comparison**: Constant-time to prevent timing attacks
- **Migration**: Automatic upgrade from legacy hashes on login

### Bluesky AT Protocol Authentication

SynthChat supports federated authentication via the [AT Protocol](https://atproto.com/) (used by Bluesky):

- **Decentralized Identity (DID)**: Users are identified by unique DIDs
- **Handles**: Human-readable identifiers (e.g., `user.bsky.social`)
- **App Passwords**: Recommended for third-party app authentication
- **Account Linking**: Link Bluesky accounts to existing local accounts

#### Using Bluesky Login

1. On the login screen, tap "Bluesky" in the login mode toggle
2. Enter your Bluesky handle (e.g., `yourname.bsky.social`)
3. Enter your **App Password** (not your main password)
   - Create an App Password in Bluesky → Settings → App Passwords
4. Tap "Sign In with Bluesky"

#### Federated Server Support

The AT Protocol supports federated personal data servers (PDS). While Bluesky's `bsky.social` is the default, the architecture allows for self-hosted or alternative PDS servers.

## License

See LICENSE file in the parent directory.
