/// User model for authentication with Bluesky AT Protocol support
class User {
  final int id;
  final String username;
  final String email;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? blueskyDid;
  final String? blueskyHandle;
  final String authProvider;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    this.lastLogin,
    this.blueskyDid,
    this.blueskyHandle,
    this.authProvider = 'local',
  });

  /// Check if user is authenticated via Bluesky
  bool get isBlueskyUser => authProvider == 'bluesky' || blueskyDid != null;
  
  /// Get display name (prefer Bluesky handle if available)
  String get displayName => blueskyHandle ?? username;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      username: map['username'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastLogin: map['last_login'] != null 
          ? DateTime.parse(map['last_login'] as String) 
          : null,
      blueskyDid: map['bluesky_did'] as String?,
      blueskyHandle: map['bluesky_handle'] as String?,
      authProvider: map['auth_provider'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'bluesky_did': blueskyDid,
      'bluesky_handle': blueskyHandle,
      'auth_provider': authProvider,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? blueskyDid,
    String? blueskyHandle,
    String? authProvider,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      blueskyDid: blueskyDid ?? this.blueskyDid,
      blueskyHandle: blueskyHandle ?? this.blueskyHandle,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

/// Room invitation model
class RoomInvitation {
  final int id;
  final int roomId;
  final int inviterId;
  final int inviteeId;
  final String status;
  final String message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? roomName;
  final String? inviterUsername;
  final String? inviteeUsername;

  RoomInvitation({
    required this.id,
    required this.roomId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    this.message = '',
    required this.createdAt,
    this.respondedAt,
    this.roomName,
    this.inviterUsername,
    this.inviteeUsername,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory RoomInvitation.fromMap(Map<String, dynamic> map) {
    return RoomInvitation(
      id: map['id'] as int,
      roomId: map['room_id'] as int,
      inviterId: map['inviter_id'] as int,
      inviteeId: map['invitee_id'] as int,
      status: map['status'] as String? ?? 'pending',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      respondedAt: map['responded_at'] != null
          ? DateTime.parse(map['responded_at'] as String)
          : null,
      roomName: map['room_name'] as String?,
      inviterUsername: map['inviter_username'] as String?,
      inviteeUsername: map['invitee_username'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': status,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}
