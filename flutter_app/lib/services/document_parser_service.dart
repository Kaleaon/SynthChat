import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'settings_service.dart';

/// Document import model for V4: AI-powered document parsing
class DocumentImport {
  final int id;
  final int userId;
  final String filename;
  final String fileType;
  final String parsedData;
  final int? characterId;
  final String status;
  final DateTime createdAt;

  DocumentImport({
    required this.id,
    required this.userId,
    required this.filename,
    required this.fileType,
    this.parsedData = '',
    this.characterId,
    this.status = 'pending',
    required this.createdAt,
  });

  factory DocumentImport.fromMap(Map<String, dynamic> map) {
    return DocumentImport(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      filename: map['filename'] as String,
      fileType: map['file_type'] as String,
      parsedData: map['parsed_data'] as String? ?? '',
      characterId: map['character_id'] as int?,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Parse the parsed data as a map
  Map<String, dynamic> get parsedDataMap {
    if (parsedData.isEmpty) return {};
    try {
      return jsonDecode(parsedData) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Extracted character data from document parsing
class ExtractedCharacterData {
  final String name;
  final String description;
  final String personality;
  final String systemPrompt;
  final String greeting;
  final Map<String, dynamic> traits;
  final String backstory;

  ExtractedCharacterData({
    required this.name,
    this.description = '',
    this.personality = '',
    this.systemPrompt = '',
    this.greeting = '',
    this.traits = const {},
    this.backstory = '',
  });

  factory ExtractedCharacterData.fromMap(Map<String, dynamic> map) {
    return ExtractedCharacterData(
      name: map['name'] as String? ?? 'Unknown',
      description: map['description'] as String? ?? '',
      personality: map['personality'] as String? ?? '',
      systemPrompt: map['system_prompt'] as String? ?? '',
      greeting: map['greeting'] as String? ?? '',
      traits: map['traits'] as Map<String, dynamic>? ?? {},
      backstory: map['backstory'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'personality': personality,
      'system_prompt': systemPrompt,
      'greeting': greeting,
      'traits': traits,
      'backstory': backstory,
    };
  }
}

/// Service for parsing documents and creating characters (V4)
class DocumentParserService extends ChangeNotifier {
  final DatabaseService _db;
  SettingsService? _settingsService;
  List<DocumentImport> _imports = [];
  bool _isProcessing = false;
  String _processingStatus = '';

  DocumentParserService(this._db);

  List<DocumentImport> get imports => _imports;
  bool get isProcessing => _isProcessing;
  String get processingStatus => _processingStatus;

  /// Set settings service for API configuration
  void setSettingsService(SettingsService service) {
    _settingsService = service;
  }

  /// Load all document imports for a user
  Future<void> loadImports(int userId) async {
    try {
      final importMaps = await _db.getUserDocumentImports(userId);
      _imports = importMaps.map((m) => DocumentImport.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading document imports: $e');
    }
  }

  /// Import and parse a document file
  Future<ExtractedCharacterData?> importDocument({
    required int userId,
    required String filePath,
    required String filename,
  }) async {
    _isProcessing = true;
    _processingStatus = 'Reading file...';
    notifyListeners();

    try {
      // Determine file type
      final fileType = _getFileType(filename);
      
      // Create import record
      final importMap = await _db.createDocumentImport(
        userId: userId,
        filename: filename,
        fileType: fileType,
      );

      if (importMap == null) {
        throw Exception('Failed to create import record');
      }

      final importId = importMap['id'] as int;

      // Read and parse file content
      _processingStatus = 'Parsing document...';
      notifyListeners();

      final content = await _readFileContent(filePath, fileType);

      // Extract character data using AI or heuristics
      _processingStatus = 'Extracting character data...';
      notifyListeners();

      final extractedData = await _extractCharacterData(content, fileType);

      // Update import record
      await _db.updateDocumentImport(
        importId,
        status: 'completed',
        parsedData: jsonEncode(extractedData.toMap()),
      );

      // Reload imports
      await loadImports(userId);

      _isProcessing = false;
      _processingStatus = '';
      notifyListeners();

      return extractedData;
    } catch (e) {
      print('Error importing document: $e');
      _isProcessing = false;
      _processingStatus = 'Error: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get file type from filename
  String _getFileType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'md':
        return 'markdown';
      case 'txt':
        return 'text';
      case 'json':
        return 'json';
      case 'html':
      case 'htm':
        return 'html';
      case 'pdf':
        return 'pdf';
      default:
        return 'text';
    }
  }

  /// Read file content based on type
  Future<String> _readFileContent(String filePath, String fileType) async {
    final file = File(filePath);
    
    if (fileType == 'pdf') {
      // PDF parsing would require additional packages
      // For now, return empty string and handle in extraction
      return 'PDF support requires additional configuration';
    }

    return await file.readAsString();
  }

  /// Extract character data from content using AI or heuristics
  Future<ExtractedCharacterData> _extractCharacterData(
    String content,
    String fileType,
  ) async {
    // Try AI extraction first if settings are configured
    if (_settingsService != null && _settingsService!.isConfigured) {
      try {
        return await _extractWithAI(content);
      } catch (e) {
        debugPrint('AI extraction failed, falling back to heuristics: $e');
      }
    }

    // Fall back to heuristic extraction
    return _extractWithHeuristics(content, fileType);
  }

  /// Extract character data using LLM API
  Future<ExtractedCharacterData> _extractWithAI(String content) async {
    if (_settingsService == null || !_settingsService!.isConfigured) {
      throw Exception('Settings not configured');
    }

    // Truncate content to avoid exceeding token limits (~12K chars ≈ 3K tokens)
    final truncatedContent = content.length > 12000 
        ? '${content.substring(0, 12000)}...[truncated]' 
        : content;
    
    final prompt = '''
Analyze the following document and extract character information. Return a JSON object with these fields:
- name: The character's name
- description: A brief description of the character
- personality: Personality traits and characteristics
- system_prompt: A system prompt for an AI to roleplay as this character
- greeting: How the character would greet someone
- traits: A JSON object of specific traits (e.g., {"brave": 0.8, "intelligent": 0.9})
- backstory: The character's background story

Document content:
$truncatedContent

Return only valid JSON.
''';

    try {
      final apiKey = _settingsService!.apiKey;
      final apiEndpoint = _settingsService!.apiEndpoint;
      
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _settingsService!.model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 1000,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('OpenAI API request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Safely access nested JSON response
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          final responseContent = message?['content'] as String?;
          if (responseContent != null) {
            // Parse JSON from response
            final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseContent);
            if (jsonMatch != null) {
              final characterData = jsonDecode(jsonMatch.group(0)!);
              return ExtractedCharacterData.fromMap(characterData);
            }
          }
        }
      }
    } on TimeoutException {
      debugPrint('AI extraction timed out');
    } catch (e) {
      debugPrint('AI extraction error: $e');
    }

    throw Exception('AI extraction failed');
  }

  /// Extract character data using heuristics
  ExtractedCharacterData _extractWithHeuristics(String content, String fileType) {
    String name = 'Unknown Character';
    String description = '';
    String personality = '';
    String backstory = '';
    String greeting = '';
    final traits = <String, dynamic>{};

    if (fileType == 'json') {
      try {
        final data = jsonDecode(content);
        return ExtractedCharacterData.fromMap(data);
      } catch (_) {}
    }

    // Parse markdown/text format
    final lines = content.split('\n');
    String currentSection = '';

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Check for headers (markdown style)
      if (trimmedLine.startsWith('#')) {
        final headerText = trimmedLine.replaceAll(RegExp(r'^#+\s*'), '').toLowerCase();
        
        if (headerText.contains('name') || lines.indexOf(line) == 0) {
          // First header might be the name
          if (!headerText.contains('name')) {
            name = trimmedLine.replaceAll(RegExp(r'^#+\s*'), '');
          }
          currentSection = 'name';
        } else if (headerText.contains('description') || headerText.contains('about')) {
          currentSection = 'description';
        } else if (headerText.contains('personality') || headerText.contains('traits')) {
          currentSection = 'personality';
        } else if (headerText.contains('backstory') || headerText.contains('background') || headerText.contains('history')) {
          currentSection = 'backstory';
        } else if (headerText.contains('greeting') || headerText.contains('hello')) {
          currentSection = 'greeting';
        }
        continue;
      }

      // Parse key: value pairs
      if (trimmedLine.contains(':')) {
        final parts = trimmedLine.split(':');
        final key = parts[0].trim().toLowerCase();
        final value = parts.sublist(1).join(':').trim();

        if (key == 'name') {
          name = value;
        } else if (key == 'description') {
          description = value;
        } else if (key == 'personality') {
          personality = value;
        } else if (key == 'greeting') {
          greeting = value;
        }
        continue;
      }

      // Add to current section
      if (trimmedLine.isNotEmpty) {
        switch (currentSection) {
          case 'name':
            if (name == 'Unknown Character') name = trimmedLine;
            break;
          case 'description':
            description += '$trimmedLine ';
            break;
          case 'personality':
            personality += '$trimmedLine ';
            break;
          case 'backstory':
            backstory += '$trimmedLine ';
            break;
          case 'greeting':
            greeting += '$trimmedLine ';
            break;
        }
      }
    }

    // Generate system prompt from extracted data
    final systemPrompt = _generateSystemPrompt(name, description, personality, backstory);

    // Generate default greeting if not found
    if (greeting.isEmpty) {
      greeting = "Hello! I'm $name. It's nice to meet you!";
    }

    return ExtractedCharacterData(
      name: name.trim(),
      description: description.trim(),
      personality: personality.trim(),
      systemPrompt: systemPrompt,
      greeting: greeting.trim(),
      traits: traits,
      backstory: backstory.trim(),
    );
  }

  /// Generate a system prompt from character data
  String _generateSystemPrompt(
    String name,
    String description,
    String personality,
    String backstory,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('You are $name.');
    
    if (description.isNotEmpty) {
      buffer.writeln('\nDescription: $description');
    }
    
    if (personality.isNotEmpty) {
      buffer.writeln('\nPersonality: $personality');
    }
    
    if (backstory.isNotEmpty) {
      buffer.writeln('\nBackstory: $backstory');
    }

    buffer.writeln('\nStay in character at all times. Respond as $name would.');

    return buffer.toString().trim();
  }

  /// Create character from extracted data
  Future<Map<String, dynamic>?> createCharacterFromExtracted({
    required int userId,
    required ExtractedCharacterData data,
  }) async {
    return await _db.createCharacter(
      userId: userId,
      name: data.name,
      description: data.description,
      personality: data.personality,
      systemPrompt: data.systemPrompt,
      greeting: data.greeting,
    );
  }
}
