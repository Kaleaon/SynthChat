import 'dart:convert';

/// App settings model for API configuration
class AppSettings {
  final int id;
  final int userId;
  final String llmProvider;
  final String apiKey;
  final String apiEndpoint;
  final String model;
  final double temperature;
  final int maxTokens;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    required this.id,
    required this.userId,
    this.llmProvider = 'openai',
    this.apiKey = '',
    this.apiEndpoint = '',
    this.model = 'gpt-3.5-turbo',
    this.temperature = 0.7,
    this.maxTokens = 500,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      llmProvider: map['llm_provider'] as String? ?? 'openai',
      apiKey: map['api_key'] as String? ?? '',
      apiEndpoint: map['api_endpoint'] as String? ?? '',
      model: map['model'] as String? ?? 'gpt-3.5-turbo',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: map['max_tokens'] as int? ?? 500,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'llm_provider': llmProvider,
      'api_key': apiKey,
      'api_endpoint': apiEndpoint,
      'model': model,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AppSettings copyWith({
    int? id,
    int? userId,
    String? llmProvider,
    String? apiKey,
    String? apiEndpoint,
    String? model,
    double? temperature,
    int? maxTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      llmProvider: llmProvider ?? this.llmProvider,
      apiKey: apiKey ?? this.apiKey,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the API endpoint URL based on provider
  String get effectiveApiEndpoint {
    if (apiEndpoint.isNotEmpty) {
      return apiEndpoint;
    }
    
    // Default endpoints for different providers
    // Note: Gemini endpoint is constructed dynamically in ChatService
    switch (llmProvider.toLowerCase()) {
      case 'openai':
        return 'https://api.openai.com/v1/chat/completions';
      case 'gemini':
        // Base URL - actual endpoint constructed in ChatService with model
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      case 'anthropic':
        return 'https://api.anthropic.com/v1/messages';
      default:
        return '';
    }
  }

  /// Get default model for provider
  String get effectiveModel {
    if (model.isNotEmpty) {
      return model;
    }

    switch (llmProvider.toLowerCase()) {
      case 'openai':
        return 'gpt-3.5-turbo';
      case 'gemini':
        return 'gemini-pro';
      case 'anthropic':
        return 'claude-3-sonnet-20240229';
      default:
        return 'gpt-3.5-turbo';
    }
  }

  /// Check if settings are valid
  bool get isValid {
    return apiKey.isNotEmpty && llmProvider.isNotEmpty;
  }
}
