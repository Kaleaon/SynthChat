import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Database service for local SQLite storage
class DatabaseService {
  static Database? _database;
  static Completer<void>? _initCompleter;
  
  // PBKDF2 configuration for secure password hashing
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 32;
  static const int _keyLength = 32;

  Future<Database> get database async {
    if (_database != null) return _database!;
    await init();
    return _database!;
  }

  /// Initialize the database with synchronization to prevent race conditions
  Future<void> init() async {
    // If already initialized, return immediately
    if (_database != null) return;
    
    // If initialization is in progress, wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    
    // Start initialization
    _initCompleter = Completer<void>();
    
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'synthchat.db');

      _database = await openDatabase(
        path,
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table with salt for PBKDF2 and Bluesky AT Protocol support
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        bluesky_did TEXT,
        bluesky_handle TEXT,
        auth_provider TEXT DEFAULT 'local',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_login TEXT
      )
    ''');

    // Characters table with mood tracking and evolution fields
    await db.execute('''
      CREATE TABLE characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        avatar_path TEXT DEFAULT 'default.png',
        description TEXT DEFAULT '',
        personality TEXT DEFAULT '',
        system_prompt TEXT DEFAULT '',
        greeting TEXT DEFAULT 'Hello! How can I help you?',
        model TEXT DEFAULT 'gpt-3.5-turbo',
        temperature REAL DEFAULT 0.7,
        max_tokens INTEGER DEFAULT 500,
        traits TEXT DEFAULT '{}',
        mood_state TEXT DEFAULT '{"current": "neutral", "intensity": 0.5}',
        personality_evolution TEXT DEFAULT '[]',
        memory_context TEXT DEFAULT '',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Messages table with extended metadata
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        thought_pattern TEXT DEFAULT '',
        emotion TEXT DEFAULT 'neutral',
        mood_impact REAL DEFAULT 0.0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
      )
    ''');

    // Rooms table for V2: collaborative character interactions
    await db.execute('''
      CREATE TABLE rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_id INTEGER NOT NULL,
        is_public INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Room participants
    await db.execute('''
      CREATE TABLE room_participants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        character_id INTEGER,
        joined_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL
      )
    ''');

    // Memory branches for V3: private conversation forking
    await db.execute('''
      CREATE TABLE memory_branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        parent_branch_id INTEGER,
        name TEXT NOT NULL,
        is_private INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
        FOREIGN KEY (parent_branch_id) REFERENCES memory_branches (id) ON DELETE SET NULL
      )
    ''');

    // Document imports for V4: AI-powered document parsing
    await db.execute('''
      CREATE TABLE document_imports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        filename TEXT NOT NULL,
        file_type TEXT NOT NULL,
        parsed_data TEXT DEFAULT '',
        character_id INTEGER,
        status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL
      )
    ''');

    // Personality evolution log for V5
    await db.execute('''
      CREATE TABLE personality_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        character_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        description TEXT NOT NULL,
        trait_changes TEXT DEFAULT '{}',
        mood_changes TEXT DEFAULT '{}',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE
      )
    ''');

    // Room invitations for user invites
    await db.execute('''
      CREATE TABLE room_invitations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        inviter_id INTEGER NOT NULL,
        invitee_id INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        message TEXT DEFAULT '',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        responded_at TEXT,
        FOREIGN KEY (room_id) REFERENCES rooms (id) ON DELETE CASCADE,
        FOREIGN KEY (inviter_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (invitee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // App settings table for API configuration
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        llm_provider TEXT DEFAULT 'openai',
        api_key TEXT DEFAULT '',
        api_endpoint TEXT DEFAULT '',
        model TEXT DEFAULT 'gpt-3.5-turbo',
        temperature REAL DEFAULT 0.7,
        max_tokens INTEGER DEFAULT 500,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(user_id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for existing tables
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT DEFAULT ""');
      await db.execute('ALTER TABLE characters ADD COLUMN mood_state TEXT DEFAULT \'{"current": "neutral", "intensity": 0.5}\'');
      await db.execute('ALTER TABLE characters ADD COLUMN personality_evolution TEXT DEFAULT \'[]\'');
      await db.execute('ALTER TABLE characters ADD COLUMN memory_context TEXT DEFAULT \'\'');
      await db.execute('ALTER TABLE messages ADD COLUMN mood_impact REAL DEFAULT 0.0');
      
      // Create new tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          owner_id INTEGER NOT NULL,
          is_public INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS room_participants (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          character_id INTEGER,
          joined_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS memory_branches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          character_id INTEGER NOT NULL,
          parent_branch_id INTEGER,
          name TEXT NOT NULL,
          is_private INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS document_imports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          filename TEXT NOT NULL,
          file_type TEXT NOT NULL,
          parsed_data TEXT DEFAULT '',
          character_id INTEGER,
          status TEXT DEFAULT 'pending',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS personality_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          character_id INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          description TEXT NOT NULL,
          trait_changes TEXT DEFAULT '{}',
          mood_changes TEXT DEFAULT '{}',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add Bluesky AT Protocol fields to users table
      await db.execute('ALTER TABLE users ADD COLUMN bluesky_did TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN bluesky_handle TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN auth_provider TEXT DEFAULT "local"');

      // Create room invitations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS room_invitations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_id INTEGER NOT NULL,
          inviter_id INTEGER NOT NULL,
          invitee_id INTEGER NOT NULL,
          status TEXT DEFAULT 'pending',
          message TEXT DEFAULT '',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          responded_at TEXT
        )
      ''');
    }

    if (oldVersion < 4) {
      // Create app settings table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          llm_provider TEXT DEFAULT 'openai',
          api_key TEXT DEFAULT '',
          api_endpoint TEXT DEFAULT '',
          model TEXT DEFAULT 'gpt-3.5-turbo',
          temperature REAL DEFAULT 0.7,
          max_tokens INTEGER DEFAULT 500,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user_id)
        )
      ''');
    }
  }

  /// Generate a cryptographically secure random salt
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Hash a password using PBKDF2 with HMAC-SHA256
  /// This is a secure password hashing method with high iteration count
  String _pbkdf2Hash(String password, String salt) {
    final saltBytes = base64.decode(salt);
    final passwordBytes = utf8.encode(password);
    
    // PBKDF2 implementation using HMAC-SHA256
    Uint8List result = Uint8List(_keyLength);
    final hmac = Hmac(sha256, passwordBytes);
    
    int blockCount = (_keyLength / 32).ceil();
    int offset = 0;
    
    for (int block = 1; block <= blockCount; block++) {
      // U1 = PRF(Password, Salt || INT(i))
      final blockBytes = ByteData(4)..setInt32(0, block, Endian.big);
      var u = hmac.convert([...saltBytes, ...blockBytes.buffer.asUint8List()]).bytes;
      var t = List<int>.from(u);
      
      // U2 through Uc
      for (int i = 1; i < _pbkdf2Iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      
      // Copy to result
      for (int i = 0; i < t.length && offset < _keyLength; i++) {
        result[offset++] = t[i];
      }
    }
    
    return base64.encode(result);
  }

  /// Hash password with PBKDF2 (returns salt:hash format)
  String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _pbkdf2Hash(password, salt);
    return '$salt:$hash';
  }

  /// Verify password against stored hash
  bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    
    final salt = parts[0];
    final hash = parts[1];
    final computedHash = _pbkdf2Hash(password, salt);
    
    // Constant-time comparison to prevent timing attacks
    if (hash.length != computedHash.length) return false;
    int result = 0;
    for (int i = 0; i < hash.length; i++) {
      result |= hash.codeUnitAt(i) ^ computedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  // ==================== User Methods ====================

  /// Create a new user with secure PBKDF2 password hashing
  Future<Map<String, dynamic>?> createUser(
      String username, String email, String password) async {
    final db = await database;
    final salt = _generateSalt();
    final passwordHash = _pbkdf2Hash(password, salt);

    try {
      final id = await db.insert('users', {
        'username': username,
        'email': email.toLowerCase(),
        'password_hash': passwordHash,
        'password_salt': salt,
        'created_at': DateTime.now().toIso8601String(),
      });

      return await getUserById(id);
    } catch (e) {
      debugPrint('Error creating user: $e');
      return null;
    }
  }

  /// Authenticate a user using secure PBKDF2 verification
  Future<Map<String, dynamic>?> authenticateUser(
      String username, String password) async {
    final db = await database;

    // First, find the user by username or email
    final results = await db.query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [username, username.toLowerCase()],
    );

    if (results.isNotEmpty) {
      final user = results.first;
      final storedHash = user['password_hash'] as String;
      final storedSalt = user['password_salt'] as String? ?? '';
      
      bool isValid = false;
      
      // Check if using new PBKDF2 format (has salt)
      if (storedSalt.isNotEmpty) {
        final computedHash = _pbkdf2Hash(password, storedSalt);
        // Constant-time comparison
        if (storedHash.length == computedHash.length) {
          int result = 0;
          for (int i = 0; i < storedHash.length; i++) {
            result |= storedHash.codeUnitAt(i) ^ computedHash.codeUnitAt(i);
          }
          isValid = result == 0;
        }
      } else {
        // Legacy SHA-256 format (for migration) - verify and upgrade
        final legacyHash = sha256.convert(utf8.encode(password)).toString();
        if (legacyHash == storedHash) {
          isValid = true;
          // Upgrade to PBKDF2
          final newSalt = _generateSalt();
          final newHash = _pbkdf2Hash(password, newSalt);
          await db.update(
            'users',
            {'password_hash': newHash, 'password_salt': newSalt},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
      
      if (isValid) {
        // Update last login
        await db.update(
          'users',
          {'last_login': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [user['id']],
        );
        return user;
      }
    }
    return null;
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Check if username exists
  Future<bool> usernameExists(String username) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return results.isNotEmpty;
  }

  /// Check if email exists
  Future<bool> emailExists(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    return results.isNotEmpty;
  }

  // ==================== Character Methods ====================

  /// Create a new character
  Future<Map<String, dynamic>?> createCharacter({
    required int userId,
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
    final db = await database;
    final now = DateTime.now().toIso8601String();

    if (systemPrompt.isEmpty) {
      systemPrompt = 'You are $name. $personality';
    }
    if (greeting.isEmpty) {
      greeting = "Hello! I'm $name. How can I help you today?";
    }

    try {
      final id = await db.insert('characters', {
        'user_id': userId,
        'name': name,
        'personality': personality,
        'system_prompt': systemPrompt,
        'greeting': greeting,
        'avatar_path': avatarPath,
        'description': description,
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'traits': '{}',
        'created_at': now,
        'updated_at': now,
      });

      return await getCharacter(id);
    } catch (e) {
      debugPrint('Error creating character: $e');
      return null;
    }
  }

  /// Get a character by ID
  Future<Map<String, dynamic>?> getCharacter(int id) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT c.*, 
             (SELECT COUNT(*) FROM messages WHERE character_id = c.id) as message_count
      FROM characters c
      WHERE c.id = ?
    ''', [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all characters for a user
  Future<List<Map<String, dynamic>>> getCharacters(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*, 
             (SELECT COUNT(*) FROM messages WHERE character_id = c.id) as message_count
      FROM characters c
      WHERE user_id = ?
      ORDER BY updated_at DESC
    ''', [userId]);
  }

  /// Update a character
  Future<bool> updateCharacter(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();

    try {
      await db.update(
        'characters',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating character: $e');
      return false;
    }
  }

  /// Delete a character
  Future<bool> deleteCharacter(int id) async {
    final db = await database;

    try {
      // Delete messages first
      await db.delete('messages', where: 'character_id = ?', whereArgs: [id]);
      // Delete character
      await db.delete('characters', where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Error deleting character: $e');
      return false;
    }
  }

  // ==================== Message Methods ====================

  /// Add a message
  Future<Map<String, dynamic>?> addMessage({
    required int characterId,
    required String role,
    required String content,
    String thoughtPattern = '',
    String emotion = 'neutral',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final id = await db.insert('messages', {
        'character_id': characterId,
        'role': role,
        'content': content,
        'thought_pattern': thoughtPattern,
        'emotion': emotion,
        'created_at': now,
      });

      // Update character's updated_at
      await db.update(
        'characters',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [characterId],
      );

      final results =
          await db.query('messages', where: 'id = ?', whereArgs: [id]);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error adding message: $e');
      return null;
    }
  }

  /// Get messages for a character
  Future<List<Map<String, dynamic>>> getMessages(int characterId,
      {int limit = 50}) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Clear messages for a character
  Future<bool> clearMessages(int characterId) async {
    final db = await database;

    try {
      await db.delete(
        'messages',
        where: 'character_id = ?',
        whereArgs: [characterId],
      );
      return true;
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return false;
    }
  }

  // ==================== V2: Room Methods ====================

  /// Create a new room for collaborative interactions
  /// Uses a transaction to ensure atomicity
  Future<Map<String, dynamic>?> createRoom({
    required String name,
    required int ownerId,
    bool isPublic = false,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      late int id;
      await db.transaction((txn) async {
        id = await txn.insert('rooms', {
          'name': name,
          'owner_id': ownerId,
          'is_public': isPublic ? 1 : 0,
          'created_at': now,
        });

        // Add owner as participant
        await txn.insert('room_participants', {
          'room_id': id,
          'user_id': ownerId,
          'joined_at': now,
        });
      });

      return await getRoom(id);
    } catch (e) {
      debugPrint('Error creating room: $e');
      return null;
    }
  }

  /// Get a room by ID
  Future<Map<String, dynamic>?> getRoom(int id) async {
    final db = await database;
    final results = await db.query(
      'rooms',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all rooms for a user (owned or participating)
  Future<List<Map<String, dynamic>>> getUserRooms(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT r.*, 
             (SELECT COUNT(*) FROM room_participants WHERE room_id = r.id) as participant_count
      FROM rooms r
      LEFT JOIN room_participants rp ON r.id = rp.room_id
      WHERE r.owner_id = ? OR rp.user_id = ?
      ORDER BY r.created_at DESC
    ''', [userId, userId]);
  }

  /// Add a participant to a room
  Future<bool> addRoomParticipant({
    required int roomId,
    required int userId,
    int? characterId,
  }) async {
    final db = await database;

    try {
      await db.insert('room_participants', {
        'room_id': roomId,
        'user_id': userId,
        'character_id': characterId,
        'joined_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding room participant: $e');
      return false;
    }
  }

  /// Remove a participant from a room
  Future<bool> removeRoomParticipant(int roomId, int userId) async {
    final db = await database;

    try {
      await db.delete(
        'room_participants',
        where: 'room_id = ? AND user_id = ?',
        whereArgs: [roomId, userId],
      );
      return true;
    } catch (e) {
      debugPrint('Error removing room participant: $e');
      return false;
    }
  }

  /// Get room participants
  Future<List<Map<String, dynamic>>> getRoomParticipants(int roomId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT rp.*, u.username, c.name as character_name
      FROM room_participants rp
      LEFT JOIN users u ON rp.user_id = u.id
      LEFT JOIN characters c ON rp.character_id = c.id
      WHERE rp.room_id = ?
    ''', [roomId]);
  }

  // ==================== V3: Memory Branch Methods ====================

  /// Create a memory branch (fork) for private conversations
  Future<Map<String, dynamic>?> createMemoryBranch({
    required int characterId,
    required String name,
    int? parentBranchId,
    bool isPrivate = true,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final id = await db.insert('memory_branches', {
        'character_id': characterId,
        'parent_branch_id': parentBranchId,
        'name': name,
        'is_private': isPrivate ? 1 : 0,
        'created_at': now,
      });

      return await getMemoryBranch(id);
    } catch (e) {
      debugPrint('Error creating memory branch: $e');
      return null;
    }
  }

  /// Get a memory branch by ID
  Future<Map<String, dynamic>?> getMemoryBranch(int id) async {
    final db = await database;
    final results = await db.query(
      'memory_branches',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get all memory branches for a character
  Future<List<Map<String, dynamic>>> getCharacterMemoryBranches(int characterId) async {
    final db = await database;
    return await db.query(
      'memory_branches',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );
  }

  /// Merge a branch back to parent (share memory with main)
  Future<bool> mergeMemoryBranch(int branchId) async {
    final db = await database;

    try {
      final branch = await getMemoryBranch(branchId);
      if (branch == null) return false;

      // Mark branch as merged (no longer private)
      await db.update(
        'memory_branches',
        {'is_private': 0},
        where: 'id = ?',
        whereArgs: [branchId],
      );

      return true;
    } catch (e) {
      debugPrint('Error merging memory branch: $e');
      return false;
    }
  }

  // ==================== V4: Document Import Methods ====================

  /// Create a document import record
  Future<Map<String, dynamic>?> createDocumentImport({
    required int userId,
    required String filename,
    required String fileType,
    String parsedData = '',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final id = await db.insert('document_imports', {
        'user_id': userId,
        'filename': filename,
        'file_type': fileType,
        'parsed_data': parsedData,
        'status': 'pending',
        'created_at': now,
      });

      return await getDocumentImport(id);
    } catch (e) {
      debugPrint('Error creating document import: $e');
      return null;
    }
  }

  /// Get a document import by ID
  Future<Map<String, dynamic>?> getDocumentImport(int id) async {
    final db = await database;
    final results = await db.query(
      'document_imports',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update document import status and parsed data
  Future<bool> updateDocumentImport(int id, {
    String? status,
    String? parsedData,
    int? characterId,
  }) async {
    final db = await database;
    final data = <String, dynamic>{};
    
    if (status != null) data['status'] = status;
    if (parsedData != null) data['parsed_data'] = parsedData;
    if (characterId != null) data['character_id'] = characterId;

    try {
      await db.update(
        'document_imports',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating document import: $e');
      return false;
    }
  }

  /// Get all document imports for a user
  Future<List<Map<String, dynamic>>> getUserDocumentImports(int userId) async {
    final db = await database;
    return await db.query(
      'document_imports',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ==================== V5: Personality Evolution Methods ====================

  /// Log a personality event (mood change, trait evolution, etc.)
  Future<Map<String, dynamic>?> logPersonalityEvent({
    required int characterId,
    required String eventType,
    required String description,
    Map<String, dynamic>? traitChanges,
    Map<String, dynamic>? moodChanges,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final id = await db.insert('personality_events', {
        'character_id': characterId,
        'event_type': eventType,
        'description': description,
        'trait_changes': jsonEncode(traitChanges ?? {}),
        'mood_changes': jsonEncode(moodChanges ?? {}),
        'created_at': now,
      });

      return await getPersonalityEvent(id);
    } catch (e) {
      debugPrint('Error logging personality event: $e');
      return null;
    }
  }

  /// Get a personality event by ID
  Future<Map<String, dynamic>?> getPersonalityEvent(int id) async {
    final db = await database;
    final results = await db.query(
      'personality_events',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get personality events for a character
  Future<List<Map<String, dynamic>>> getCharacterPersonalityEvents(
    int characterId, {
    int limit = 50,
  }) async {
    final db = await database;
    return await db.query(
      'personality_events',
      where: 'character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Update character mood state
  Future<bool> updateCharacterMood(int characterId, Map<String, dynamic> moodState) async {
    final db = await database;

    try {
      await db.update(
        'characters',
        {
          'mood_state': jsonEncode(moodState),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [characterId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating character mood: $e');
      return false;
    }
  }

  /// Add personality evolution entry
  Future<bool> addPersonalityEvolution(int characterId, Map<String, dynamic> evolution) async {
    final db = await database;

    try {
      final character = await getCharacter(characterId);
      if (character == null) return false;

      List<dynamic> evolutions = [];
      try {
        final existing = character['personality_evolution'] as String? ?? '[]';
        evolutions = jsonDecode(existing) as List<dynamic>;
      } catch (_) {}

      evolution['timestamp'] = DateTime.now().toIso8601String();
      evolutions.add(evolution);

      await db.update(
        'characters',
        {
          'personality_evolution': jsonEncode(evolutions),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [characterId],
      );
      return true;
    } catch (e) {
      debugPrint('Error adding personality evolution: $e');
      return false;
    }
  }

  /// Get character's current mood
  Future<Map<String, dynamic>> getCharacterMood(int characterId) async {
    final character = await getCharacter(characterId);
    if (character == null) {
      return {'current': 'neutral', 'intensity': 0.5};
    }

    try {
      final moodJson = character['mood_state'] as String? ?? '{"current": "neutral", "intensity": 0.5}';
      return jsonDecode(moodJson) as Map<String, dynamic>;
    } catch (_) {
      return {'current': 'neutral', 'intensity': 0.5};
    }
  }

  /// Update character memory context
  Future<bool> updateCharacterMemoryContext(int characterId, String context) async {
    final db = await database;

    try {
      await db.update(
        'characters',
        {
          'memory_context': context,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [characterId],
      );
      return true;
    } catch (e) {
      debugPrint('Error updating character memory context: $e');
      return false;
    }
  }

  // ==================== Room Invitation Methods ====================

  /// Create a room invitation
  Future<Map<String, dynamic>?> createRoomInvitation({
    required int roomId,
    required int inviterId,
    required int inviteeId,
    String message = '',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      // Check if invitation already exists
      final existing = await db.query(
        'room_invitations',
        where: 'room_id = ? AND invitee_id = ? AND status = ?',
        whereArgs: [roomId, inviteeId, 'pending'],
      );
      if (existing.isNotEmpty) {
        return null; // Already invited
      }

      final id = await db.insert('room_invitations', {
        'room_id': roomId,
        'inviter_id': inviterId,
        'invitee_id': inviteeId,
        'message': message,
        'status': 'pending',
        'created_at': now,
      });

      return await getRoomInvitation(id);
    } catch (e) {
      debugPrint('Error creating room invitation: $e');
      return null;
    }
  }

  /// Get a room invitation by ID
  Future<Map<String, dynamic>?> getRoomInvitation(int id) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ri.*, r.name as room_name, 
             inviter.username as inviter_username,
             invitee.username as invitee_username
      FROM room_invitations ri
      LEFT JOIN rooms r ON ri.room_id = r.id
      LEFT JOIN users inviter ON ri.inviter_id = inviter.id
      LEFT JOIN users invitee ON ri.invitee_id = invitee.id
      WHERE ri.id = ?
    ''', [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Get pending invitations for a user (invitations they received)
  Future<List<Map<String, dynamic>>> getPendingInvitations(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ri.*, r.name as room_name, 
             inviter.username as inviter_username
      FROM room_invitations ri
      LEFT JOIN rooms r ON ri.room_id = r.id
      LEFT JOIN users inviter ON ri.inviter_id = inviter.id
      WHERE ri.invitee_id = ? AND ri.status = 'pending'
      ORDER BY ri.created_at DESC
    ''', [userId]);
  }

  /// Get sent invitations for a user
  Future<List<Map<String, dynamic>>> getSentInvitations(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ri.*, r.name as room_name, 
             invitee.username as invitee_username
      FROM room_invitations ri
      LEFT JOIN rooms r ON ri.room_id = r.id
      LEFT JOIN users invitee ON ri.invitee_id = invitee.id
      WHERE ri.inviter_id = ?
      ORDER BY ri.created_at DESC
    ''', [userId]);
  }

  /// Accept a room invitation
  /// Uses a transaction to ensure atomicity
  Future<bool> acceptRoomInvitation(int invitationId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final invitation = await getRoomInvitation(invitationId);
      if (invitation == null || invitation['status'] != 'pending') {
        return false;
      }

      await db.transaction((txn) async {
        // Update invitation status
        await txn.update(
          'room_invitations',
          {'status': 'accepted', 'responded_at': now},
          where: 'id = ?',
          whereArgs: [invitationId],
        );

        // Add user as room participant
        await txn.insert('room_participants', {
          'room_id': invitation['room_id'] as int,
          'user_id': invitation['invitee_id'] as int,
          'joined_at': now,
        });
      });

      return true;
    } catch (e) {
      debugPrint('Error accepting room invitation: $e');
      return false;
    }
  }

  /// Reject a room invitation
  Future<bool> rejectRoomInvitation(int invitationId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      await db.update(
        'room_invitations',
        {'status': 'rejected', 'responded_at': now},
        where: 'id = ?',
        whereArgs: [invitationId],
      );
      return true;
    } catch (e) {
      debugPrint('Error rejecting room invitation: $e');
      return false;
    }
  }

  /// Cancel a room invitation (by inviter)
  Future<bool> cancelRoomInvitation(int invitationId) async {
    final db = await database;

    try {
      await db.delete(
        'room_invitations',
        where: 'id = ?',
        whereArgs: [invitationId],
      );
      return true;
    } catch (e) {
      debugPrint('Error cancelling room invitation: $e');
      return false;
    }
  }

  /// Get invitations for a room (sent by owner/participants)
  Future<List<Map<String, dynamic>>> getRoomInvitations(int roomId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ri.*, invitee.username as invitee_username
      FROM room_invitations ri
      LEFT JOIN users invitee ON ri.invitee_id = invitee.id
      WHERE ri.room_id = ?
      ORDER BY ri.created_at DESC
    ''', [roomId]);
  }

  /// Find user by username or email (for inviting)
  Future<Map<String, dynamic>?> findUserByUsernameOrEmail(String query) async {
    final db = await database;
    final normalizedQuery = query.trim().toLowerCase();
    
    final results = await db.query(
      'users',
      where: 'LOWER(username) = ? OR LOWER(email) = ?',
      whereArgs: [normalizedQuery, normalizedQuery],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ==================== Bluesky AT Protocol Methods ====================

  /// Create or update a user with Bluesky credentials
  Future<Map<String, dynamic>?> createBlueskyUser({
    required String blueskyDid,
    required String blueskyHandle,
    String? email,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      // Check if user with this DID already exists
      final existing = await db.query(
        'users',
        where: 'bluesky_did = ?',
        whereArgs: [blueskyDid],
      );

      if (existing.isNotEmpty) {
        // Update existing user
        await db.update(
          'users',
          {
            'bluesky_handle': blueskyHandle,
            'last_login': now,
          },
          where: 'bluesky_did = ?',
          whereArgs: [blueskyDid],
        );
        return await getUserByBlueskyDid(blueskyDid);
      }

      // Create new user with Bluesky credentials
      // Use handle as username (with @bsky suffix to avoid collisions)
      final username = '${blueskyHandle.split('.').first}_bsky';
      final userEmail = email ?? '$blueskyHandle@bsky.social';

      final id = await db.insert('users', {
        'username': username,
        'email': userEmail,
        'password_hash': '', // No password for Bluesky users
        'password_salt': '',
        'bluesky_did': blueskyDid,
        'bluesky_handle': blueskyHandle,
        'auth_provider': 'bluesky',
        'created_at': now,
        'last_login': now,
      });

      return await getUserById(id);
    } catch (e) {
      debugPrint('Error creating Bluesky user: $e');
      return null;
    }
  }

  /// Get user by Bluesky DID
  Future<Map<String, dynamic>?> getUserByBlueskyDid(String did) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'bluesky_did = ?',
      whereArgs: [did],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Link Bluesky account to existing user
  Future<bool> linkBlueskyAccount(int userId, String blueskyDid, String blueskyHandle) async {
    final db = await database;

    try {
      await db.update(
        'users',
        {
          'bluesky_did': blueskyDid,
          'bluesky_handle': blueskyHandle,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      debugPrint('Error linking Bluesky account: $e');
      return false;
    }
  }

  /// Unlink Bluesky account from user
  Future<bool> unlinkBlueskyAccount(int userId) async {
    final db = await database;

    try {
      await db.update(
        'users',
        {
          'bluesky_did': null,
          'bluesky_handle': null,
          'auth_provider': 'local',
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      debugPrint('Error unlinking Bluesky account: $e');
      return false;
    }
  }

  // ============================================================================
  // App Settings Methods
  // ============================================================================

  /// Get app settings for a user
  Future<Map<String, dynamic>?> getAppSettings(int userId) async {
    final db = await database;
    final results = await db.query(
      'app_settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Create or update app settings for a user
  Future<bool> saveAppSettings({
    required int userId,
    required String llmProvider,
    required String apiKey,
    String apiEndpoint = '',
    String model = 'gpt-3.5-turbo',
    double temperature = 0.7,
    int maxTokens = 500,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      final existing = await getAppSettings(userId);
      
      if (existing != null) {
        // Update existing settings
        await db.update(
          'app_settings',
          {
            'llm_provider': llmProvider,
            'api_key': apiKey,
            'api_endpoint': apiEndpoint,
            'model': model,
            'temperature': temperature,
            'max_tokens': maxTokens,
            'updated_at': now,
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      } else {
        // Insert new settings
        await db.insert('app_settings', {
          'user_id': userId,
          'llm_provider': llmProvider,
          'api_key': apiKey,
          'api_endpoint': apiEndpoint,
          'model': model,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'created_at': now,
          'updated_at': now,
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving app settings: $e');
      return false;
    }
  }

  /// Delete app settings for a user
  Future<bool> deleteAppSettings(int userId) async {
    final db = await database;
    try {
      await db.delete(
        'app_settings',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      debugPrint('Error deleting app settings: $e');
      return false;
    }
  }
}
