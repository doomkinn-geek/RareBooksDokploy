import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local storage
class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _languageKey = 'app_language';
  static const String _userIdKey = 'user_id';
  static const String _themeKey = 'app_theme';
  
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;
  
  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );
  
  /// Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // ==================== Secure Storage (for sensitive data) ====================
  
  /// Save authentication token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }
  
  /// Get authentication token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }
  
  /// Delete authentication token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }
  
  /// Check if user is authenticated
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  /// Clear all secure storage
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }
  
  // ==================== Shared Preferences (for app settings) ====================
  
  /// Save app language
  Future<void> saveLanguage(String language) async {
    await _prefs?.setString(_languageKey, language);
  }
  
  /// Get app language
  String getLanguage() {
    return _prefs?.getString(_languageKey) ?? 'ru';
  }
  
  /// Save user ID
  Future<void> saveUserId(int userId) async {
    await _prefs?.setInt(_userIdKey, userId);
  }
  
  /// Get user ID
  int? getUserId() {
    return _prefs?.getInt(_userIdKey);
  }
  
  /// Delete user ID
  Future<void> deleteUserId() async {
    await _prefs?.remove(_userIdKey);
  }
  
  /// Save theme mode (light/dark/system)
  Future<void> saveTheme(String theme) async {
    await _prefs?.setString(_themeKey, theme);
  }
  
  /// Get theme mode
  String getTheme() {
    return _prefs?.getString(_themeKey) ?? 'system';
  }
  
  /// Clear all user data (on logout)
  Future<void> clearUserData() async {
    await deleteToken();
    await deleteUserId();
  }
  
  /// Clear all storage
  Future<void> clearAll() async {
    await clearSecureStorage();
    await _prefs?.clear();
  }
}

