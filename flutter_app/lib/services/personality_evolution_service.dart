import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Mood state for a character
class MoodState {
  final String current;
  final double intensity;
  final DateTime lastUpdated;

  MoodState({
    required this.current,
    required this.intensity,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory MoodState.fromMap(Map<String, dynamic> map) {
    return MoodState(
      current: map['current'] as String? ?? 'neutral',
      intensity: (map['intensity'] as num?)?.toDouble() ?? 0.5,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current': current,
      'intensity': intensity,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// Get emoji for current mood
  String get emoji {
    switch (current.toLowerCase()) {
      case 'happy':
      case 'joyful':
        return '😊';
      case 'sad':
      case 'melancholy':
        return '😢';
      case 'angry':
      case 'frustrated':
        return '😠';
      case 'excited':
      case 'enthusiastic':
        return '🤩';
      case 'curious':
      case 'interested':
        return '🤔';
      case 'calm':
      case 'peaceful':
        return '😌';
      case 'anxious':
      case 'worried':
        return '😰';
      case 'playful':
      case 'mischievous':
        return '😏';
      case 'loving':
      case 'affectionate':
        return '🥰';
      case 'confused':
        return '😕';
      default:
        return '😐';
    }
  }

  /// Get color for mood visualization
  int get color {
    switch (current.toLowerCase()) {
      case 'happy':
      case 'joyful':
        return 0xFFFFD700; // Gold
      case 'sad':
      case 'melancholy':
        return 0xFF4169E1; // Royal Blue
      case 'angry':
      case 'frustrated':
        return 0xFFDC143C; // Crimson
      case 'excited':
      case 'enthusiastic':
        return 0xFFFF4500; // Orange Red
      case 'curious':
      case 'interested':
        return 0xFF9370DB; // Medium Purple
      case 'calm':
      case 'peaceful':
        return 0xFF98FB98; // Pale Green
      case 'anxious':
      case 'worried':
        return 0xFFFFB347; // Pastel Orange
      case 'playful':
      case 'mischievous':
        return 0xFFFF69B4; // Hot Pink
      case 'loving':
      case 'affectionate':
        return 0xFFFF1493; // Deep Pink
      default:
        return 0xFF808080; // Gray
    }
  }
}

/// Personality event for tracking evolution
class PersonalityEvent {
  final int id;
  final int characterId;
  final String eventType;
  final String description;
  final Map<String, dynamic> traitChanges;
  final Map<String, dynamic> moodChanges;
  final DateTime createdAt;

  PersonalityEvent({
    required this.id,
    required this.characterId,
    required this.eventType,
    required this.description,
    this.traitChanges = const {},
    this.moodChanges = const {},
    required this.createdAt,
  });

  factory PersonalityEvent.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parseJsonField(dynamic field) {
      if (field == null) return {};
      if (field is Map<String, dynamic>) return field;
      if (field is String) {
        try {
          return jsonDecode(field) as Map<String, dynamic>;
        } catch (_) {
          return {};
        }
      }
      return {};
    }

    return PersonalityEvent(
      id: map['id'] as int,
      characterId: map['character_id'] as int,
      eventType: map['event_type'] as String,
      description: map['description'] as String,
      traitChanges: parseJsonField(map['trait_changes']),
      moodChanges: parseJsonField(map['mood_changes']),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Get icon for event type
  String get icon {
    switch (eventType.toLowerCase()) {
      case 'mood_shift':
        return '🌡️';
      case 'trait_growth':
        return '📈';
      case 'trait_decline':
        return '📉';
      case 'memory_formed':
        return '💭';
      case 'relationship_change':
        return '💫';
      case 'insight':
        return '💡';
      case 'conflict':
        return '⚡';
      case 'resolution':
        return '🤝';
      default:
        return '📝';
    }
  }
}

/// Service for managing personality evolution and mood tracking (V5)
class PersonalityEvolutionService extends ChangeNotifier {
  final DatabaseService _db;
  MoodState? _currentMood;
  List<PersonalityEvent> _events = [];
  Map<String, double> _currentTraits = {};
  bool _isLoading = false;

  PersonalityEvolutionService(this._db);

  MoodState? get currentMood => _currentMood;
  List<PersonalityEvent> get events => _events;
  Map<String, double> get currentTraits => _currentTraits;
  bool get isLoading => _isLoading;

  /// Available moods for selection
  static const List<String> availableMoods = [
    'neutral',
    'happy',
    'sad',
    'angry',
    'excited',
    'curious',
    'calm',
    'anxious',
    'playful',
    'loving',
    'confused',
    'frustrated',
    'melancholy',
    'enthusiastic',
    'peaceful',
    'worried',
    'mischievous',
    'affectionate',
  ];

  /// Load mood and events for a character
  Future<void> loadCharacterPersonality(int characterId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load current mood
      final moodMap = await _db.getCharacterMood(characterId);
      _currentMood = MoodState.fromMap(moodMap);

      // Load personality events
      final eventMaps = await _db.getCharacterPersonalityEvents(characterId);
      _events = eventMaps.map((m) => PersonalityEvent.fromMap(m)).toList();

      // Load current traits from character
      final character = await _db.getCharacter(characterId);
      if (character != null) {
        try {
          final traitsJson = character['traits'] as String? ?? '{}';
          final traitsMap = jsonDecode(traitsJson);
          _currentTraits = Map<String, double>.from(
            (traitsMap as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
          );
        } catch (_) {
          _currentTraits = {};
        }
      }
    } catch (e) {
      print('Error loading character personality: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update character mood based on interaction
  Future<void> updateMood(int characterId, String newMood, double intensity) async {
    try {
      final oldMood = _currentMood?.current ?? 'neutral';
      
      final moodState = MoodState(
        current: newMood,
        intensity: intensity.clamp(0.0, 1.0),
      );

      await _db.updateCharacterMood(characterId, moodState.toMap());
      _currentMood = moodState;

      // Log mood shift event
      if (oldMood != newMood) {
        await logEvent(
          characterId: characterId,
          eventType: 'mood_shift',
          description: 'Mood shifted from $oldMood to $newMood',
          moodChanges: {'from': oldMood, 'to': newMood, 'intensity': intensity},
        );
      }

      notifyListeners();
    } catch (e) {
      print('Error updating mood: $e');
    }
  }

  /// Analyze message sentiment and update mood accordingly
  Future<String> analyzeAndUpdateMood(int characterId, String message, String response) async {
    // Simple sentiment analysis using keyword matching
    final sentiment = _analyzeSentiment(message, response);
    final newMood = _mapSentimentToMood(sentiment);
    final intensity = _calculateIntensity(message, response);

    await updateMood(characterId, newMood, intensity);

    return newMood;
  }

  /// Simple sentiment analysis
  double _analyzeSentiment(String message, String response) {
    final positiveWords = [
      'happy', 'love', 'great', 'wonderful', 'amazing', 'excellent',
      'fantastic', 'awesome', 'good', 'nice', 'thank', 'appreciate',
      'excited', 'joy', 'fun', 'beautiful', 'perfect', 'glad',
    ];
    
    final negativeWords = [
      'sad', 'angry', 'bad', 'terrible', 'awful', 'hate',
      'horrible', 'upset', 'frustrated', 'annoyed', 'disappointed',
      'worried', 'anxious', 'afraid', 'scared', 'hurt', 'sorry',
    ];

    final combined = '${message.toLowerCase()} ${response.toLowerCase()}';
    
    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in positiveWords) {
      if (combined.contains(word)) positiveCount++;
    }

    for (final word in negativeWords) {
      if (combined.contains(word)) negativeCount++;
    }

    if (positiveCount == 0 && negativeCount == 0) return 0.0;
    
    return (positiveCount - negativeCount) / (positiveCount + negativeCount);
  }

  /// Map sentiment score to mood
  String _mapSentimentToMood(double sentiment) {
    if (sentiment > 0.5) return 'happy';
    if (sentiment > 0.2) return 'curious';
    if (sentiment < -0.5) return 'sad';
    if (sentiment < -0.2) return 'worried';
    return 'neutral';
  }

  /// Calculate intensity based on message characteristics
  double _calculateIntensity(String message, String response) {
    // Base intensity
    double intensity = 0.5;

    // Increase for exclamation marks
    intensity += (message.split('!').length - 1) * 0.1;
    intensity += (response.split('!').length - 1) * 0.05;

    // Increase for question marks (curiosity)
    intensity += (message.split('?').length - 1) * 0.05;

    // Increase for caps
    if (message.toUpperCase() == message && message.length > 3) {
      intensity += 0.2;
    }

    return intensity.clamp(0.0, 1.0);
  }

  /// Log a personality event
  Future<void> logEvent({
    required int characterId,
    required String eventType,
    required String description,
    Map<String, dynamic>? traitChanges,
    Map<String, dynamic>? moodChanges,
  }) async {
    try {
      final eventMap = await _db.logPersonalityEvent(
        characterId: characterId,
        eventType: eventType,
        description: description,
        traitChanges: traitChanges,
        moodChanges: moodChanges,
      );

      if (eventMap != null) {
        _events.insert(0, PersonalityEvent.fromMap(eventMap));
        notifyListeners();
      }
    } catch (e) {
      print('Error logging personality event: $e');
    }
  }

  /// Evolve traits based on interactions
  Future<void> evolveTrait(int characterId, String traitName, double change) async {
    try {
      final currentValue = _currentTraits[traitName] ?? 0.5;
      final newValue = (currentValue + change).clamp(0.0, 1.0);

      _currentTraits[traitName] = newValue;

      // Update character traits
      await _db.updateCharacter(characterId, {
        'traits': jsonEncode(_currentTraits),
      });

      // Log trait change event
      final eventType = change > 0 ? 'trait_growth' : 'trait_decline';
      await logEvent(
        characterId: characterId,
        eventType: eventType,
        description: '$traitName ${change > 0 ? "increased" : "decreased"} by ${(change * 100).abs().toStringAsFixed(1)}%',
        traitChanges: {
          traitName: {'from': currentValue, 'to': newValue, 'change': change}
        },
      );

      // Add to personality evolution log
      await _db.addPersonalityEvolution(characterId, {
        'trait': traitName,
        'old_value': currentValue,
        'new_value': newValue,
        'reason': 'Interaction-based evolution',
      });

      notifyListeners();
    } catch (e) {
      print('Error evolving trait: $e');
    }
  }

  /// Automatically evolve personality based on conversation
  Future<void> autoEvolve(int characterId, String userMessage, String aiResponse) async {
    // Analyze the interaction for trait impacts
    final traitImpacts = _analyzeTraitImpacts(userMessage, aiResponse);

    for (final entry in traitImpacts.entries) {
      if (entry.value.abs() > 0.01) {
        await evolveTrait(characterId, entry.key, entry.value);
      }
    }
  }

  /// Analyze interaction for trait impacts
  Map<String, double> _analyzeTraitImpacts(String userMessage, String aiResponse) {
    final impacts = <String, double>{};
    final combined = '${userMessage.toLowerCase()} ${aiResponse.toLowerCase()}';

    // Empathy/Kindness
    if (combined.contains('help') || combined.contains('care') || combined.contains('understand')) {
      impacts['empathy'] = 0.02;
    }

    // Curiosity
    if (combined.contains('why') || combined.contains('how') || combined.contains('what')) {
      impacts['curiosity'] = 0.02;
    }

    // Humor
    if (combined.contains('joke') || combined.contains('funny') || combined.contains('laugh')) {
      impacts['humor'] = 0.02;
    }

    // Confidence
    if (combined.contains('can') || combined.contains('will') || combined.contains('definitely')) {
      impacts['confidence'] = 0.01;
    }

    // Patience
    if (userMessage.length > 200) {
      impacts['patience'] = 0.01;
    }

    return impacts;
  }

  /// Generate internal reasoning/thought pattern
  String generateInternalReasoning(String userMessage, MoodState? mood) {
    final reasoning = StringBuffer();
    final random = Random();

    // Add mood-based internal state
    if (mood != null) {
      reasoning.writeln('[Internal State: ${mood.current} (${(mood.intensity * 100).toInt()}%)]');
    }

    // Add observation
    if (userMessage.contains('?')) {
      reasoning.writeln('*Notices they have a question*');
    } else if (userMessage.endsWith('!')) {
      reasoning.writeln('*Senses their enthusiasm*');
    } else {
      reasoning.writeln('*Considers their words carefully*');
    }

    // Add random internal thought
    final thoughts = [
      '*Takes a moment to reflect*',
      '*Considers how to best respond*',
      '*Draws on past experiences*',
      '*Feels connection to this conversation*',
      '*Notices subtle emotions in their message*',
    ];
    reasoning.writeln(thoughts[random.nextInt(thoughts.length)]);

    return reasoning.toString();
  }
}
