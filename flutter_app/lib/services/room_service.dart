import 'package:flutter/foundation.dart';
import 'database_service.dart';

/// Room model for V2: collaborative character interactions
class Room {
  final int id;
  final String name;
  final int ownerId;
  final bool isPublic;
  final DateTime createdAt;
  final int participantCount;

  Room({
    required this.id,
    required this.name,
    required this.ownerId,
    this.isPublic = false,
    required this.createdAt,
    this.participantCount = 0,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as int,
      name: map['name'] as String,
      ownerId: map['owner_id'] as int,
      isPublic: (map['is_public'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      participantCount: map['participant_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'is_public': isPublic ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Room participant model
class RoomParticipant {
  final int id;
  final int roomId;
  final int userId;
  final int? characterId;
  final String? username;
  final String? characterName;
  final DateTime joinedAt;

  RoomParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    this.characterId,
    this.username,
    this.characterName,
    required this.joinedAt,
  });

  factory RoomParticipant.fromMap(Map<String, dynamic> map) {
    return RoomParticipant(
      id: map['id'] as int,
      roomId: map['room_id'] as int,
      userId: map['user_id'] as int,
      characterId: map['character_id'] as int?,
      username: map['username'] as String?,
      characterName: map['character_name'] as String?,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }
}

/// Service for managing rooms and collaborative interactions (V2)
class RoomService extends ChangeNotifier {
  final DatabaseService _db;
  List<Room> _rooms = [];
  Room? _currentRoom;
  List<RoomParticipant> _currentParticipants = [];
  bool _isLoading = false;

  RoomService(this._db);

  List<Room> get rooms => _rooms;
  Room? get currentRoom => _currentRoom;
  List<RoomParticipant> get currentParticipants => _currentParticipants;
  bool get isLoading => _isLoading;

  /// Load all rooms for a user
  Future<void> loadRooms(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final roomMaps = await _db.getUserRooms(userId);
      _rooms = roomMaps.map((m) => Room.fromMap(m)).toList();
    } catch (e) {
      print('Error loading rooms: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new room
  Future<Room?> createRoom({
    required String name,
    required int ownerId,
    bool isPublic = false,
  }) async {
    try {
      final roomMap = await _db.createRoom(
        name: name,
        ownerId: ownerId,
        isPublic: isPublic,
      );

      if (roomMap != null) {
        final room = Room.fromMap(roomMap);
        _rooms.insert(0, room);
        notifyListeners();
        return room;
      }
    } catch (e) {
      print('Error creating room: $e');
    }
    return null;
  }

  /// Join a room
  Future<bool> joinRoom(int roomId, int userId, {int? characterId}) async {
    try {
      final success = await _db.addRoomParticipant(
        roomId: roomId,
        userId: userId,
        characterId: characterId,
      );

      if (success) {
        await loadRoomParticipants(roomId);
      }
      return success;
    } catch (e) {
      print('Error joining room: $e');
      return false;
    }
  }

  /// Leave a room
  Future<bool> leaveRoom(int roomId, int userId) async {
    try {
      final success = await _db.removeRoomParticipant(roomId, userId);
      if (success) {
        await loadRoomParticipants(roomId);
      }
      return success;
    } catch (e) {
      print('Error leaving room: $e');
      return false;
    }
  }

  /// Set current room and load participants
  Future<void> setCurrentRoom(int roomId) async {
    final roomMap = await _db.getRoom(roomId);
    if (roomMap != null) {
      _currentRoom = Room.fromMap(roomMap);
      await loadRoomParticipants(roomId);
      notifyListeners();
    }
  }

  /// Load participants for a room
  Future<void> loadRoomParticipants(int roomId) async {
    try {
      final participantMaps = await _db.getRoomParticipants(roomId);
      _currentParticipants = participantMaps.map((m) => RoomParticipant.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading room participants: $e');
    }
  }

  /// Clear current room
  void clearCurrentRoom() {
    _currentRoom = null;
    _currentParticipants = [];
    notifyListeners();
  }
}
