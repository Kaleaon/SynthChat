/// Chat message model
class Message {
  final int id;
  final int characterId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String thoughtPattern;
  final String emotion;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.characterId,
    required this.role,
    required this.content,
    this.thoughtPattern = '',
    this.emotion = 'neutral',
    required this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int,
      characterId: map['character_id'] as int,
      role: map['role'] as String,
      content: map['content'] as String,
      thoughtPattern: map['thought_pattern'] as String? ?? '',
      emotion: map['emotion'] as String? ?? 'neutral',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'character_id': characterId,
      'role': role,
      'content': content,
      'thought_pattern': thoughtPattern,
      'emotion': emotion,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    int? id,
    int? characterId,
    String? role,
    String? content,
    String? thoughtPattern,
    String? emotion,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      role: role ?? this.role,
      content: content ?? this.content,
      thoughtPattern: thoughtPattern ?? this.thoughtPattern,
      emotion: emotion ?? this.emotion,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get emoji for emotion
  String get emotionEmoji {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'empathetic':
        return '🤗';
      case 'curious':
        return '🤔';
      case 'helpful':
        return '💡';
      case 'friendly':
        return '😄';
      default:
        return '😐';
    }
  }
}
