import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'bluesky_auth_service.dart';

/// Authentication service with local and Bluesky AT Protocol support
class AuthService extends ChangeNotifier {
  final DatabaseService _db;
  BlueskyAuthService? _blueskyAuth;
  User? _currentUser;
  bool _isLoading = false;

  AuthService(this._db) {
    _loadSession();
  }

  /// Set the Bluesky auth service (for dependency injection)
  void setBlueskyAuth(BlueskyAuthService blueskyAuth) {
    _blueskyAuth = blueskyAuth;
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isBlueskyUser => _currentUser?.isBlueskyUser ?? false;

  /// Load saved session
  Future<void> _loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        final userData = await _db.getUserById(userId);
        if (userData != null) {
          _currentUser = User.fromMap(userData);
        }
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // RFC 5322 compliant email regex
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );

  /// Register a new user
  Future<(bool, String)> register(
      String username, String email, String password) async {
    // Normalize and validate inputs
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim().toLowerCase();
    
    if (normalizedUsername.length < 3) {
      return (false, 'Username must be at least 3 characters');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      return (false, 'Please enter a valid email address');
    }
    if (password.length < 6) {
      return (false, 'Password must be at least 6 characters');
    }

    // Check if username exists
    if (await _db.usernameExists(normalizedUsername)) {
      return (false, 'Username already taken');
    }

    // Check if email exists
    if (await _db.emailExists(normalizedEmail)) {
      return (false, 'Email already registered');
    }

    // Create user (password is hashed in DatabaseService.createUser)
    final userData = await _db.createUser(normalizedUsername, normalizedEmail, password);
    if (userData == null) {
      return (false, 'Failed to create account');
    }

    _currentUser = User.fromMap(userData);
    await _saveSession();
    notifyListeners();

    return (true, 'Account created successfully');
  }

  /// Log in a user
  Future<(bool, String)> login(String username, String password) async {
    final userData = await _db.authenticateUser(username, password);

    if (userData == null) {
      return (false, 'Invalid username or password');
    }

    _currentUser = User.fromMap(userData);
    await _saveSession();
    notifyListeners();

    return (true, 'Login successful');
  }

  /// Log out (handles both local and Bluesky sessions)
  Future<void> logout() async {
    // If user was logged in via Bluesky, also logout from Bluesky
    if (_currentUser?.isBlueskyUser == true && _blueskyAuth != null) {
      await _blueskyAuth!.logout();
    }
    
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_provider');
    notifyListeners();
  }

  /// Save session to shared preferences
  Future<void> _saveSession() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', _currentUser!.id);
      await prefs.setString('auth_provider', _currentUser!.authProvider);
    }
  }

  // ==================== Bluesky AT Protocol Authentication ====================

  /// Login with Bluesky using handle and app password
  /// 
  /// The AT Protocol provides decentralized authentication:
  /// - Users can use their Bluesky handle (e.g., user.bsky.social)
  /// - Or any AT Protocol compatible handle from federated servers
  /// - App passwords are recommended for security
  Future<(bool, String)> loginWithBluesky(String handle, String appPassword) async {
    if (_blueskyAuth == null) {
      return (false, 'Bluesky authentication not configured');
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Authenticate with Bluesky
      final (success, message) = await _blueskyAuth!.login(handle, appPassword);
      
      if (!success) {
        _isLoading = false;
        notifyListeners();
        return (false, message);
      }

      // Get or create local user linked to Bluesky account
      final user = await _blueskyAuth!.getOrCreateLocalUser();
      
      if (user == null) {
        await _blueskyAuth!.logout();
        _isLoading = false;
        notifyListeners();
        return (false, 'Failed to create local account');
      }

      _currentUser = user;
      await _saveSession();
      
      _isLoading = false;
      notifyListeners();
      
      return (true, 'Successfully logged in as ${user.blueskyHandle ?? user.username}');
    } catch (e) {
      debugPrint('Bluesky login error: $e');
      _isLoading = false;
      notifyListeners();
      return (false, 'Bluesky login failed. Please try again.');
    }
  }

  /// Link existing local account to Bluesky
  Future<(bool, String)> linkBlueskyAccount(String handle, String appPassword) async {
    if (_blueskyAuth == null) {
      return (false, 'Bluesky authentication not configured');
    }

    if (_currentUser == null) {
      return (false, 'Please log in first');
    }

    try {
      // Authenticate with Bluesky
      final (success, message) = await _blueskyAuth!.login(handle, appPassword);
      
      if (!success) {
        return (false, message);
      }

      final session = _blueskyAuth!.session;
      if (session == null) {
        return (false, 'Failed to get Bluesky session');
      }

      // Link the Bluesky account to local user
      final linked = await _db.linkBlueskyAccount(
        _currentUser!.id,
        session.did,
        session.handle,
      );

      if (!linked) {
        return (false, 'Failed to link Bluesky account');
      }

      // Refresh user data
      final userData = await _db.getUserById(_currentUser!.id);
      if (userData != null) {
        _currentUser = User.fromMap(userData);
        notifyListeners();
      }

      return (true, 'Bluesky account linked successfully');
    } catch (e) {
      debugPrint('Error linking Bluesky account: $e');
      return (false, 'Failed to link Bluesky account');
    }
  }

  /// Unlink Bluesky account from local user
  Future<(bool, String)> unlinkBlueskyAccount() async {
    if (_currentUser == null) {
      return (false, 'Not logged in');
    }

    if (_currentUser!.authProvider == 'bluesky') {
      return (false, 'Cannot unlink Bluesky from a Bluesky-only account');
    }

    try {
      final success = await _db.unlinkBlueskyAccount(_currentUser!.id);
      
      if (success) {
        // Logout from Bluesky
        await _blueskyAuth?.logout();
        
        // Refresh user data
        final userData = await _db.getUserById(_currentUser!.id);
        if (userData != null) {
          _currentUser = User.fromMap(userData);
          notifyListeners();
        }

        return (true, 'Bluesky account unlinked');
      }
      return (false, 'Failed to unlink Bluesky account');
    } catch (e) {
      debugPrint('Error unlinking Bluesky account: $e');
      return (false, 'Failed to unlink Bluesky account');
    }
  }
}
