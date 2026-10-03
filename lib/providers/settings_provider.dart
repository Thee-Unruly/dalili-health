import 'package:flutter/material.dart';

/// Supported execution backends for the AI architecture.
enum AIBackend { local, groq }

/// Holds user-facing preferences that aren't tied to model state.
/// Model download/selection/deletion now lives in OfflineModelProvider —
/// see settings_screen.dart, which reads that provider directly.
class SettingsProvider with ChangeNotifier {
  bool _socraticMode = true;
  bool _powerMode = true;
  String _sourceLanguage = 'EN';
  String _targetLanguage = 'SW';

  // New backend state tracking
  AIBackend _activeBackend = AIBackend.local;
  String _groqApiKey = '';

  bool get socraticMode => _socraticMode;
  bool get powerMode => _powerMode;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;

  // New Getters
  AIBackend get activeBackend => _activeBackend;
  String get groqApiKey => _groqApiKey;

  void toggleSocraticMode(bool value) {
    _socraticMode = value;
    notifyListeners();
  }

  void togglePowerMode(bool value) {
    _powerMode = value;
    notifyListeners();
  }

  void setLanguages(String source, String target) {
    _sourceLanguage = source;
    _targetLanguage = target;
    notifyListeners();
  }

  // New Methods to resolve compilation errors
  void setActiveBackend(AIBackend backend) {
    _activeBackend = backend;
    notifyListeners();
  }

  void setGroqApiKey(String value) {
    _groqApiKey = value;
    notifyListeners();
  }
}