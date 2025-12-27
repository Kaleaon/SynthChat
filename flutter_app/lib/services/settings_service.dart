import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import 'database_service.dart';

/// Service for managing app settings
class SettingsService extends ChangeNotifier {
  final DatabaseService _db;
  AppSettings? _settings;
  int? _userId;

  SettingsService(this._db);

  AppSettings? get settings => _settings;

  /// Set current user ID and load their settings
  Future<void> setUserId(int? userId) async {
    _userId = userId;
    if (userId != null) {
      await loadSettings();
    } else {
      _settings = null;
      notifyListeners();
    }
  }

  /// Load settings for the current user
  Future<void> loadSettings() async {
    if (_userId == null) return;

    try {
      final data = await _db.getAppSettings(_userId!);
      if (data != null) {
        _settings = AppSettings.fromMap(data);
      } else {
        // Create default settings
        _settings = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Save settings
  Future<bool> saveSettings({
    required String llmProvider,
    required String apiKey,
    String apiEndpoint = '',
    String model = '',
    double? temperature,
    int? maxTokens,
  }) async {
    if (_userId == null) return false;

    try {
      final success = await _db.saveAppSettings(
        userId: _userId!,
        llmProvider: llmProvider,
        apiKey: apiKey,
        apiEndpoint: apiEndpoint,
        model: model.isEmpty ? _getDefaultModel(llmProvider) : model,
        temperature: temperature ?? 0.7,
        maxTokens: maxTokens ?? 500,
      );

      if (success) {
        await loadSettings();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  /// Get default model for a provider
  String _getDefaultModel(String provider) {
    return AppSettings.defaultModels[provider.toLowerCase()] ?? 'gpt-3.5-turbo';
  }

  /// Delete settings
  Future<bool> deleteSettings() async {
    if (_userId == null) return false;

    try {
      final success = await _db.deleteAppSettings(_userId!);
      if (success) {
        _settings = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting settings: $e');
      return false;
    }
  }

  /// Get API key (for backward compatibility)
  String? get apiKey => _settings?.apiKey;

  /// Get LLM provider
  String get llmProvider => _settings?.llmProvider ?? 'openai';

  /// Get API endpoint
  String get apiEndpoint => _settings?.effectiveApiEndpoint ?? '';

  /// Get model
  String get model => _settings?.effectiveModel ?? 'gpt-3.5-turbo';

  /// Get temperature
  double get temperature => _settings?.temperature ?? 0.7;

  /// Get max tokens
  int get maxTokens => _settings?.maxTokens ?? 500;

  /// Check if settings are configured
  bool get isConfigured => _settings?.isValid ?? false;
}
