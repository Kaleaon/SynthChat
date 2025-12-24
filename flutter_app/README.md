# SynthChat - Flutter Android App

A Silly Tavern-style multi-agent LLM manager for Android with local storage and OpenAI integration.

## Features

- 🤖 **Multiple AI Characters**: Create and manage unique AI personalities
- 💬 **Chat Interface**: Beautiful chat bubbles with message history
- 🎨 **Dark Theme**: Silly Tavern-inspired dark UI
- 🔐 **User Authentication**: Secure local login system
- 💾 **Local Storage**: SQLite database for offline access
- 🧠 **Thought Patterns**: Characters maintain internal reasoning
- 😊 **Emotion Tracking**: Messages display character emotions
- ⚙️ **Customizable LLM**: Configure model, temperature, and tokens

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
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   │   ├── user.dart
│   │   ├── character.dart
│   │   └── message.dart
│   ├── services/              # Business logic
│   │   ├── database_service.dart
│   │   ├── auth_service.dart
│   │   ├── character_service.dart
│   │   └── chat_service.dart
│   ├── screens/               # UI screens
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── characters_screen.dart
│   │   ├── chat_screen.dart
│   │   └── character_edit_screen.dart
│   ├── widgets/               # Reusable widgets
│   │   ├── character_card.dart
│   │   └── message_bubble.dart
│   └── theme/                 # App theming
│       └── app_theme.dart
├── assets/                    # Static assets
│   └── avatars/
├── pubspec.yaml              # Dependencies
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
- `crypto` - Password hashing
- `intl` - Date formatting

## License

See LICENSE file in the parent directory.
