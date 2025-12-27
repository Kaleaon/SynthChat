import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/message.dart';
import '../models/character.dart';
import 'database_service.dart';
import 'personality_evolution_service.dart';

/// Chat service for managing conversations with V5 personality evolution
class ChatService extends ChangeNotifier {
  final DatabaseService _db;
  PersonalityEvolutionService? _personalityService;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _currentThoughtPattern;
  MoodState? _currentMood;

  // OpenAI API configuration
  String? _apiKey;
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  ChatService(this._db);

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  String? get currentThoughtPattern => _currentThoughtPattern;
  MoodState? get currentMood => _currentMood;

  /// Set the OpenAI API key
  void setApiKey(String? apiKey) {
    _apiKey = apiKey;
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
      debugPrint('Error loading messages: $e');
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
      debugPrint('Error generating response: $e');
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

    // Try OpenAI API
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        final response = await _callOpenAI(character, userInput);
        if (response != null) {
          responseContent = response;
        }
      } catch (e) {
        debugPrint('OpenAI API error: $e');
      }
    }

    // Fallback response if API failed
    if (responseContent.isEmpty) {
      responseContent = "Hello! I'm ${character.name}. I received your message: \"${userInput.length > 100 ? '${userInput.substring(0, 100)}...' : userInput}\" (Configure OpenAI API key for full responses)";
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
        debugPrint('Personality evolution error: $e');
      }
    }

    return {
      'content': responseContent,
      'thought_pattern': thoughtPattern,
      'emotion': emotion,
    };
  }

  /// Call OpenAI API
  Future<String?> _callOpenAI(Character character, String userInput) async {
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
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
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
