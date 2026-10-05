import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/message.dart';
import '../models/character.dart';
import '../models/app_settings.dart';
import 'database_service.dart';
import 'personality_evolution_service.dart';
import 'settings_service.dart';

/// Chat service for managing conversations with V5 personality evolution
class ChatService extends ChangeNotifier {
  final DatabaseService _db;
  PersonalityEvolutionService? _personalityService;
  SettingsService? _settingsService;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _currentThoughtPattern;
  MoodState? _currentMood;

  ChatService(this._db);

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get currentThoughtPattern => _currentThoughtPattern;
  MoodState? get currentMood => _currentMood;

  /// Set settings service for API configuration
  void setSettingsService(SettingsService service) {
    _settingsService = service;
  }

  /// Set personality service for mood/trait tracking (V5)
  void setPersonalityService(PersonalityEvolutionService service) {
    _personalityService = service;
  }

  /// Load messages for a character
  Future<void> loadMessages(int characterId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _db.getMessages(characterId, limit: 100);
      _messages = data.map((map) => Message.fromMap(map)).toList();
    } catch (e) {
      print('Error loading messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Send a message to a character
  Future<Message?> sendMessage(Character character, String content) async {
    if (content.trim().isEmpty) return null;

    // Add user message
    final userMsgData = await _db.addMessage(
      characterId: character.id,
      role: 'user',
      content: content,
    );

    if (userMsgData != null) {
      _messages.add(Message.fromMap(userMsgData));
      notifyListeners();
    }

    // Generate response
    _isTyping = true;
    notifyListeners();

    try {
      final response = await _generateResponse(character, content);

      // Add assistant message
      final assistantMsgData = await _db.addMessage(
        characterId: character.id,
        role: 'assistant',
        content: response['content'] as String,
        thoughtPattern: response['thought_pattern'] as String? ?? '',
        emotion: response['emotion'] as String? ?? 'neutral',
      );

      if (assistantMsgData != null) {
        final assistantMsg = Message.fromMap(assistantMsgData);
        _messages.add(assistantMsg);
        _isTyping = false;
        notifyListeners();
        return assistantMsg;
      }
    } catch (e) {
      print('Error generating response: $e');
    }

    _isTyping = false;
    notifyListeners();
    return null;
  }

  /// Generate a response using LLM or fallback with V5 personality evolution
  Future<Map<String, dynamic>> _generateResponse(
      Character character, String userInput) async {
    // V5: Generate internal reasoning based on current mood
    String thoughtPattern = '';
    if (_personalityService != null) {
      _currentMood = _personalityService!.currentMood;
      thoughtPattern = _personalityService!.generateInternalReasoning(userInput, _currentMood);
      _currentThoughtPattern = thoughtPattern;
      notifyListeners();
    } else {
      // Fallback thought pattern generation
      List<String> thoughts = [];
      if (userInput.contains('?')) {
        thoughts.add('User is asking a question');
      }
      if (_messages.isNotEmpty) {
        thoughts.add('Building on ${_messages.length} previous messages');
      }
      thoughtPattern = thoughts.isNotEmpty ? thoughts.join(' | ') : 'Processing input';
    }

    // Determine emotion (will be updated by personality service after response)
    final userLower = userInput.toLowerCase();
    String emotion = _currentMood?.current ?? 'neutral';
    if (['happy', 'great', 'thanks', 'awesome', 'wonderful']
        .any((w) => userLower.contains(w))) {
      emotion = 'happy';
    } else if (['sad', 'sorry', 'bad', 'upset'].any((w) => userLower.contains(w))) {
      emotion = 'empathetic';
    } else if (userInput.contains('?')) {
      emotion = 'curious';
    }

    String responseContent = '';

    // Try LLM API if settings are configured
    if (_settingsService != null && _settingsService!.isConfigured) {
      try {
        final response = await _callLLM(character, userInput);
        if (response != null) {
          responseContent = response;
        }
      } catch (e) {
        print('LLM API error: $e');
      }
    }

    // Fallback response if API failed or not configured
    if (responseContent.isEmpty) {
      responseContent = "Hello! I'm ${character.name}. I received your message: \"${userInput.length > 100 ? '${userInput.substring(0, 100)}...' : userInput}\" (Configure API settings for full responses)";
    }

    // V5: Update personality based on interaction
    if (_personalityService != null) {
      try {
        // Analyze and update mood
        emotion = await _personalityService!.analyzeAndUpdateMood(
          character.id,
          userInput,
          responseContent,
        );
        _currentMood = _personalityService!.currentMood;

        // Auto-evolve personality traits
        await _personalityService!.autoEvolve(character.id, userInput, responseContent);
      } catch (e) {
        print('Personality evolution error: $e');
      }
    }

    return {
      'content': responseContent,
      'thought_pattern': thoughtPattern,
      'emotion': emotion,
    };
  }

  /// Call LLM API based on configured provider
  Future<String?> _callLLM(Character character, String userInput) async {
    if (_settingsService == null || !_settingsService!.isConfigured) {
      return null;
    }

    final provider = _settingsService!.llmProvider.toLowerCase();
    
    switch (provider) {
      case 'openai':
        return await _callOpenAI(character, userInput);
      case 'gemini':
        return await _callGemini(character, userInput);
      case 'anthropic':
        return await _callAnthropic(character, userInput);
      default:
        // Try as OpenAI-compatible API
        return await _callOpenAI(character, userInput);
    }
  }

  /// Call OpenAI API
  Future<String?> _callOpenAI(Character character, String userInput) async {
    if (_settingsService == null) return null;

    final apiKey = _settingsService!.apiKey;
    final apiUrl = _settingsService!.apiEndpoint;
    
    if (apiKey == null || apiKey.isEmpty) return null;

    // Build messages
    final List<Map<String, String>> apiMessages = [
      {'role': 'system', 'content': character.fullSystemPrompt},
    ];

    // Add recent conversation history (last 5 messages)
    final recentMessages = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;

    for (final msg in recentMessages) {
      apiMessages.add({
        'role': msg.role,
        'content': msg.content,
      });
    }

    apiMessages.add({'role': 'user', 'content': userInput});

    // Make API request with timeout
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': character.model,
          'messages': apiMessages,
          'temperature': character.temperature,
          'max_tokens': character.maxTokens,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('OpenAI API request timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Safely access nested JSON response
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null) {
            return content;
          }
        }
        debugPrint('OpenAI API returned unexpected response structure');
        return null;
      } else {
        debugPrint('OpenAI API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('OpenAI API request timed out');
      return null;
    }
  }

  /// Call Google Gemini API
  Future<String?> _callGemini(Character character, String userInput) async {
    if (_settingsService == null) return null;

    final apiKey = _settingsService!.apiKey;
    
    if (apiKey == null || apiKey.isEmpty) return null;

    // Build conversation context
    String conversationContext = character.fullSystemPrompt;
    
    // Add recent conversation history
    final recentMessages = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;

    for (final msg in recentMessages) {
      conversationContext += '\n${msg.role == "user" ? "User" : character.name}: ${msg.content}';
    }
    
    conversationContext += '\nUser: $userInput\n${character.name}:';

    // Make API request with timeout
    try {
      final model = character.model.isNotEmpty 
          ? character.model 
          : (AppSettings.defaultModels['gemini'] ?? 'gemini-pro');
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': conversationContext}
              ]
            }
          ],
          'generationConfig': {
            'temperature': character.temperature,
            'maxOutputTokens': character.maxTokens,
          }
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Gemini API request timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Parse Gemini response
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null) {
              return text.trim();
            }
          }
        }
        debugPrint('Gemini API returned unexpected response structure');
        return null;
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('Gemini API request timed out');
      return null;
    }
  }

  /// Call Anthropic Claude API
  Future<String?> _callAnthropic(Character character, String userInput) async {
    if (_settingsService == null) return null;

    final apiKey = _settingsService!.apiKey;
    
    if (apiKey == null || apiKey.isEmpty) return null;

    // Build messages for Claude
    final List<Map<String, String>> apiMessages = [];

    // Add recent conversation history
    final recentMessages = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;

    for (final msg in recentMessages) {
      apiMessages.add({
        'role': msg.role == 'assistant' ? 'assistant' : 'user',
        'content': msg.content,
      });
    }

    apiMessages.add({'role': 'user', 'content': userInput});

    // Make API request with timeout
    try {
      final model = character.model.isNotEmpty 
          ? character.model 
          : (AppSettings.defaultModels['anthropic'] ?? 'claude-3-sonnet-20240229');
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode({
          'model': model,
          'system': character.fullSystemPrompt,
          'messages': apiMessages,
          'temperature': character.temperature,
          'max_tokens': character.maxTokens,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Anthropic API request timed out'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Parse Claude response
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final text = content[0]['text'] as String?;
          if (text != null) {
            return text;
          }
        }
        debugPrint('Anthropic API returned unexpected response structure');
        return null;
      } else {
        debugPrint('Anthropic API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('Anthropic API request timed out');
      return null;
    }
  }

  /// Clear messages for a character
  Future<void> clearMessages(int characterId) async {
    await _db.clearMessages(characterId);
    _messages = [];
    notifyListeners();
  }

  /// Clear current messages (when switching characters)
  void clearCurrentMessages() {
    _messages = [];
    notifyListeners();
  }

  /// Add greeting message if needed
  Future<void> addGreetingIfNeeded(Character character) async {
    if (_messages.isEmpty && character.greeting.isNotEmpty) {
      final greetingData = await _db.addMessage(
        characterId: character.id,
        role: 'assistant',
        content: character.greeting,
        emotion: 'friendly',
      );

      if (greetingData != null) {
        _messages.add(Message.fromMap(greetingData));
        notifyListeners();
      }
    }
  }
}
