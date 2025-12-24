import 'package:flutter/foundation.dart';
import '../models/character.dart';
import 'database_service.dart';

/// Character management service
class CharacterService extends ChangeNotifier {
  final DatabaseService _db;
  int? _userId;
  List<Character> _characters = [];
  Character? _selectedCharacter;
  bool _isLoading = false;

  CharacterService(this._db);

  List<Character> get characters => _characters;
  Character? get selectedCharacter => _selectedCharacter;
  bool get isLoading => _isLoading;

  /// Set the current user ID
  void setUserId(int? userId) {
    if (_userId != userId) {
      _userId = userId;
      if (userId != null) {
        loadCharacters();
      } else {
        _characters = [];
        _selectedCharacter = null;
        notifyListeners();
      }
    }
  }

  /// Load all characters for the current user
  Future<void> loadCharacters() async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _db.getCharacters(_userId!);
      _characters = data.map((map) => Character.fromMap(map)).toList();
    } catch (e) {
      print('Error loading characters: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new character
  Future<(bool, String)> createCharacter({
    required String name,
    String personality = '',
    String systemPrompt = '',
    String greeting = '',
    String avatarPath = 'default.png',
    String description = '',
    String model = 'gpt-3.5-turbo',
    double temperature = 0.7,
    int maxTokens = 500,
  }) async {
    if (_userId == null) {
      return (false, 'Not logged in');
    }

    if (name.isEmpty) {
      return (false, 'Character name is required');
    }

    final data = await _db.createCharacter(
      userId: _userId!,
      name: name,
      personality: personality,
      systemPrompt: systemPrompt,
      greeting: greeting,
      avatarPath: avatarPath,
      description: description,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    if (data == null) {
      return (false, 'Failed to create character');
    }

    await loadCharacters();
    return (true, 'Character created successfully');
  }

  /// Update a character
  Future<bool> updateCharacter(int id, Map<String, dynamic> data) async {
    final success = await _db.updateCharacter(id, data);
    if (success) {
      await loadCharacters();
      // Update selected character if it's the one being edited
      if (_selectedCharacter?.id == id) {
        final charData = await _db.getCharacter(id);
        if (charData != null) {
          _selectedCharacter = Character.fromMap(charData);
          notifyListeners();
        }
      }
    }
    return success;
  }

  /// Delete a character
  Future<bool> deleteCharacter(int id) async {
    final success = await _db.deleteCharacter(id);
    if (success) {
      if (_selectedCharacter?.id == id) {
        _selectedCharacter = null;
      }
      await loadCharacters();
    }
    return success;
  }

  /// Select a character for chatting
  Future<void> selectCharacter(int id) async {
    final data = await _db.getCharacter(id);
    if (data != null) {
      _selectedCharacter = Character.fromMap(data);
      notifyListeners();
    }
  }

  /// Clear selected character
  void clearSelection() {
    _selectedCharacter = null;
    notifyListeners();
  }

  /// Get a character by ID
  Character? getCharacterById(int id) {
    try {
      return _characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
