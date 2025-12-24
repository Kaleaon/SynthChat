import 'dart:convert';

/// AI Character model
class Character {
  final int id;
  final int userId;
  final String name;
  final String avatarPath;
  final String description;
  final String personality;
  final String systemPrompt;
  final String greeting;
  final String model;
  final double temperature;
  final int maxTokens;
  final Map<String, dynamic> traits;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  Character({
    required this.id,
    required this.userId,
    required this.name,
    this.avatarPath = 'default.png',
    this.description = '',
    this.personality = '',
    this.systemPrompt = '',
    this.greeting = '',
    this.model = 'gpt-3.5-turbo',
    this.temperature = 0.7,
    this.maxTokens = 500,
    this.traits = const {},
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
  });

  factory Character.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> traitsMap = {};
    if (map['traits'] != null) {
      if (map['traits'] is String) {
        try {
          traitsMap = json.decode(map['traits'] as String);
        } catch (_) {}
      } else if (map['traits'] is Map) {
        traitsMap = Map<String, dynamic>.from(map['traits']);
      }
    }

    return Character(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      avatarPath: map['avatar_path'] as String? ?? 'default.png',
      description: map['description'] as String? ?? '',
      personality: map['personality'] as String? ?? '',
      systemPrompt: map['system_prompt'] as String? ?? '',
      greeting: map['greeting'] as String? ?? '',
      model: map['model'] as String? ?? 'gpt-3.5-turbo',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: map['max_tokens'] as int? ?? 500,
      traits: traitsMap,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      messageCount: map['message_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'avatar_path': avatarPath,
      'description': description,
      'personality': personality,
      'system_prompt': systemPrompt,
      'greeting': greeting,
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'traits': json.encode(traits),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Character copyWith({
    int? id,
    int? userId,
    String? name,
    String? avatarPath,
    String? description,
    String? personality,
    String? systemPrompt,
    String? greeting,
    String? model,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? traits,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
  }) {
    return Character(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      greeting: greeting ?? this.greeting,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      traits: traits ?? this.traits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  /// Get the full system prompt including personality
  String get fullSystemPrompt {
    if (systemPrompt.isNotEmpty) {
      return systemPrompt;
    }
    return 'You are $name. $personality';
  }
}
