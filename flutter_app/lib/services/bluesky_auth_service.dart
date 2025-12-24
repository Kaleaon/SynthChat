import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/user.dart';

/// Bluesky AT Protocol authentication session
class BlueskySession {
  final String accessJwt;
  final String refreshJwt;
  final String handle;
  final String did;
  final String? email;
  final DateTime? expiresAt;

  BlueskySession({
    required this.accessJwt,
    required this.refreshJwt,
    required this.handle,
    required this.did,
    this.email,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory BlueskySession.fromJson(Map<String, dynamic> json) {
    return BlueskySession(
      accessJwt: json['accessJwt'] as String,
      refreshJwt: json['refreshJwt'] as String,
      handle: json['handle'] as String,
      did: json['did'] as String,
      email: json['email'] as String?,
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessJwt': accessJwt,
      'refreshJwt': refreshJwt,
      'handle': handle,
      'did': did,
      'email': email,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}

/// Bluesky AT Protocol authentication service
/// 
/// Implements authentication using the AT Protocol (atproto) used by Bluesky.
/// This enables federated, decentralized identity for user authentication.
/// 
/// AT Protocol uses:
/// - DIDs (Decentralized Identifiers) for unique user identity
/// - Handles (e.g., user.bsky.social) for human-readable names
/// - JWT tokens for session management
class BlueskyAuthService extends ChangeNotifier {
  final DatabaseService _db;
  
  // Default Bluesky PDS (Personal Data Server)
  static const String _defaultPdsHost = 'bsky.social';
  
  BlueskySession? _session;
  bool _isLoading = false;
  String? _error;

  BlueskyAuthService(this._db);

  BlueskySession? get session => _session;
  bool get isAuthenticated => _session != null && !_session!.isExpired;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentHandle => _session?.handle;
  String? get currentDid => _session?.did;

  /// Get the PDS URL for a given handle
  /// Supports custom PDS hosts for federated AT Protocol servers
  String _getPdsUrl(String identifier) {
    // Check if identifier includes a custom PDS domain
    if (identifier.contains('.') && !identifier.endsWith('.bsky.social')) {
      // Extract domain from handle for custom PDS
      final parts = identifier.split('.');
      if (parts.length >= 2) {
        final domain = parts.sublist(1).join('.');
        // For now, default to bsky.social API for all handles
        // In a full implementation, we would resolve the PDS from DNS/DID doc
        return 'https://bsky.social';
      }
    }
    return 'https://$_defaultPdsHost';
  }

  /// Create a session with Bluesky using handle and app password
  /// 
  /// The AT Protocol authentication flow:
  /// 1. User provides handle (e.g., user.bsky.social) and app password
  /// 2. We call the PDS createSession endpoint
  /// 3. Server returns JWT tokens and DID
  /// 4. We store the session for future API calls
  Future<(bool, String)> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pdsUrl = _getPdsUrl(identifier);
      
      final response = await http.post(
        Uri.parse('$pdsUrl/xrpc/com.atproto.server.createSession'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        _session = BlueskySession(
          accessJwt: data['accessJwt'] as String,
          refreshJwt: data['refreshJwt'] as String,
          handle: data['handle'] as String,
          did: data['did'] as String,
          email: data['email'] as String?,
        );

        _isLoading = false;
        notifyListeners();

        return (true, 'Successfully logged in as ${_session!.handle}');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage = errorData['message'] as String? ?? 'Authentication failed';
        
        _error = errorMessage;
        _isLoading = false;
        notifyListeners();

        return (false, errorMessage);
      }
    } on TimeoutException {
      _error = 'Connection timed out. Please try again.';
      _isLoading = false;
      notifyListeners();
      return (false, _error!);
    } catch (e) {
      debugPrint('Bluesky login error: $e');
      _error = 'Failed to connect to Bluesky. Please check your credentials.';
      _isLoading = false;
      notifyListeners();
      return (false, _error!);
    }
  }

  /// Refresh the current session using the refresh token
  Future<bool> refreshSession() async {
    if (_session == null) return false;

    try {
      final pdsUrl = _getPdsUrl(_session!.handle);
      
      final response = await http.post(
        Uri.parse('$pdsUrl/xrpc/com.atproto.server.refreshSession'),
        headers: {
          'Authorization': 'Bearer ${_session!.refreshJwt}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        _session = BlueskySession(
          accessJwt: data['accessJwt'] as String,
          refreshJwt: data['refreshJwt'] as String,
          handle: data['handle'] as String,
          did: data['did'] as String,
          email: _session!.email,
        );
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing Bluesky session: $e');
    }
    return false;
  }

  /// Delete the current session (logout)
  Future<void> logout() async {
    if (_session == null) return;

    try {
      final pdsUrl = _getPdsUrl(_session!.handle);
      
      await http.post(
        Uri.parse('$pdsUrl/xrpc/com.atproto.server.deleteSession'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessJwt}',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error deleting Bluesky session: $e');
    }

    _session = null;
    _error = null;
    notifyListeners();
  }

  /// Get the user's profile from Bluesky
  Future<Map<String, dynamic>?> getProfile() async {
    if (_session == null) return null;

    try {
      final pdsUrl = _getPdsUrl(_session!.handle);
      
      final response = await http.get(
        Uri.parse('$pdsUrl/xrpc/app.bsky.actor.getProfile?actor=${_session!.did}'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessJwt}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting Bluesky profile: $e');
    }
    return null;
  }

  /// Create or get the local user account linked to this Bluesky session
  Future<User?> getOrCreateLocalUser() async {
    if (_session == null) return null;

    try {
      final userData = await _db.createBlueskyUser(
        blueskyDid: _session!.did,
        blueskyHandle: _session!.handle,
        email: _session!.email,
      );

      if (userData != null) {
        return User.fromMap(userData);
      }
    } catch (e) {
      debugPrint('Error creating local user for Bluesky: $e');
    }
    return null;
  }

  /// Resolve a DID to get the associated handle
  Future<String?> resolveHandle(String did) async {
    try {
      final response = await http.get(
        Uri.parse('https://plc.directory/$did'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final alsoKnownAs = data['alsoKnownAs'] as List<dynamic>?;
        if (alsoKnownAs != null && alsoKnownAs.isNotEmpty) {
          final handle = alsoKnownAs.first as String;
          return handle.replaceFirst('at://', '');
        }
      }
    } catch (e) {
      debugPrint('Error resolving DID: $e');
    }
    return null;
  }

  /// Check if a handle exists on Bluesky
  Future<bool> handleExists(String handle) async {
    try {
      final response = await http.get(
        Uri.parse('https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=$handle'),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Make an authenticated request to the AT Protocol API
  Future<http.Response?> makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    if (_session == null) return null;

    // Refresh session if needed
    if (_session!.isExpired) {
      final refreshed = await refreshSession();
      if (!refreshed) return null;
    }

    try {
      final pdsUrl = _getPdsUrl(_session!.handle);
      var uri = Uri.parse('$pdsUrl/xrpc/$endpoint');
      
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final headers = {
        'Authorization': 'Bearer ${_session!.accessJwt}',
        'Content-Type': 'application/json',
      };

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        default:
          return null;
      }

      return response;
    } catch (e) {
      debugPrint('AT Protocol request error: $e');
      return null;
    }
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
