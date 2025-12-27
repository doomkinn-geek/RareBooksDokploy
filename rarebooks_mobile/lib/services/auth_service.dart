import '../models/models.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Authentication service for managing user authentication state
class AuthService {
  final ApiService _apiService;
  final StorageService _storageService;
  
  User? _currentUser;
  
  AuthService({
    required ApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService;
  
  /// Get current user (cached)
  User? get currentUser => _currentUser;
  
  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;
  
  /// Check if user has active subscription
  bool get hasSubscription => _currentUser?.hasSubscription ?? false;
  
  /// Check if user has collection access
  bool get hasCollectionAccess => _currentUser?.hasCollectionAccess ?? false;
  
  /// Check if user is admin
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  
  /// Initialize authentication state
  Future<bool> initialize() async {
    try {
      final hasToken = await _storageService.hasToken();
      if (!hasToken) {
        return false;
      }
      
      // Try to get current user
      _currentUser = await _apiService.getCurrentUser();
      await _storageService.saveUserId(_currentUser!.numericId);
      return true;
    } catch (e) {
      // Token might be invalid or expired
      await _storageService.clearUserData();
      _currentUser = null;
      return false;
    }
  }
  
  /// Login user
  Future<User> login(String email, String password) async {
    final request = LoginRequest(email: email, password: password);
    final response = await _apiService.login(request);

    // Save token
    if (response.token != null) {
      await _storageService.saveToken(response.token!);
    } else {
      throw Exception('Token is null in login response');
    }

    // ALWAYS fetch full user data after login because login response 
    // only contains basic fields (email, userName, hasSubscription, role)
    // and does NOT contain id, hasCollectionAccess, currentSubscription, etc.
    _currentUser = await _apiService.getCurrentUser();
    await _storageService.saveUserId(_currentUser!.numericId);

    return _currentUser!;
  }
  
  /// Register new user
  Future<void> register({
    required String email,
    required String password,
    String? name,
    String? captchaId,
    String? captchaAnswer,
  }) async {
    final request = RegisterRequest(
      email: email,
      password: password,
      name: name,
      captchaId: captchaId,
      captchaAnswer: captchaAnswer,
    );
    
    await _apiService.register(request);
  }
  
  /// Logout user
  Future<void> logout() async {
    await _storageService.clearUserData();
    _currentUser = null;
  }
  
  /// Refresh user data
  Future<User?> refreshUser() async {
    try {
      final hasToken = await _storageService.hasToken();
      if (!hasToken) {
        _currentUser = null;
        return null;
      }
      
      _currentUser = await _apiService.getCurrentUser();
      return _currentUser;
    } catch (e) {
      // If refresh fails, clear auth state
      await logout();
      return null;
    }
  }
  
  /// Check subscription status
  Future<SubscriptionStatus> checkSubscriptionStatus() async {
    final status = await _apiService.checkSubscriptionStatus();
    
    // Refresh user data to get updated subscription info
    await refreshUser();
    
    return status;
  }
}

