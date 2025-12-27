import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Authentication state provider
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  
  AuthProvider({required AuthService authService})
      : _authService = authService;
  
  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _authService.isAuthenticated;
  User? get user => _authService.currentUser;
  bool get hasSubscription => _authService.hasSubscription;
  bool get hasCollectionAccess => _authService.hasCollectionAccess;
  bool get isAdmin => _authService.isAdmin;
  String? get errorMessage => _errorMessage;
  
  /// Initialize authentication state on app start
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _authService.initialize();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    String? name,
    String? captchaId,
    String? captchaAnswer,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _authService.register(
        email: email,
        password: password,
        name: name,
        captchaId: captchaId,
        captchaAnswer: captchaAnswer,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await _authService.logout();
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Refresh user data
  Future<void> refreshUser() async {
    try {
      await _authService.refreshUser();
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Parse error to user-friendly message
  String _parseError(dynamic error) {
    final message = error.toString();
    
    if (message.contains('401')) {
      return 'Неверный email или пароль';
    } else if (message.contains('403')) {
      return 'Доступ запрещен';
    } else if (message.contains('404')) {
      return 'Пользователь не найден';
    } else if (message.contains('409')) {
      return 'Пользователь с таким email уже существует';
    } else if (message.contains('SocketException') || 
               message.contains('Connection')) {
      return 'Ошибка соединения. Проверьте интернет-подключение';
    }
    
    return 'Произошла ошибка. Попробуйте позже';
  }
}

