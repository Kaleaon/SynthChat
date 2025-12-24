import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'database_service.dart';

// ignore: avoid_print

/// Authentication service
class AuthService extends ChangeNotifier {
  final DatabaseService _db;
  User? _currentUser;
  bool _isLoading = false;

  AuthService(this._db) {
    _loadSession();
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

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

  /// Log out
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  /// Save session to shared preferences
  Future<void> _saveSession() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', _currentUser!.id);
    }
  }
}
