import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/api_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/outbox_repository.dart';
import '../../data/repositories/status_update_queue_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/audio_storage_service.dart';
import '../../data/services/image_storage_service.dart';
import '../../data/services/status_sync_service.dart';
import '../../data/services/outbox_sync_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/encryption_service.dart';

// Утилита для форматирования ошибок
String _formatError(dynamic error) {
  if (error is DioException) {
    // Try to extract simple message from server response
    if (error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map) {
        // Handle FluentValidation errors format
        // { "errors": { "PhoneNumber": ["error1"], "Password": ["error2"] }, "title": "..." }
        if (data['errors'] != null && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          final errorMessages = <String>[];
          
          for (final entry in errors.entries) {
            if (entry.value is List && (entry.value as List).isNotEmpty) {
              // Take only the first error message for each field
              errorMessages.add((entry.value as List).first.toString());
            }
          }
          
          if (errorMessages.isNotEmpty) {
            // Return first error for cleaner display
            return errorMessages.first;
          }
        }
        
        // Extract message from various fields
        final message = data['message'] ?? data['error'] ?? data['title'];
        if (message != null && message is String) {
          // Don't show generic "One or more validation errors occurred"
          if (message.contains('validation errors occurred')) {
            return 'Проверьте правильность введённых данных';
          }
          return _simplifyMessage(message);
        }
      }
      if (data is String && !data.contains('<html') && data.length < 200) {
        return _simplifyMessage(data);
      }
    }
    
    // Simple user-friendly messages for different error types
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Проверьте интернет';
      
      case DioExceptionType.connectionError:
        return 'Нет подключения к интернету';
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Проверьте правильность введённых данных';
          case 401:
            return 'Неверный логин или пароль';
          case 403:
            return 'Доступ запрещен';
          case 404:
            return 'Данные не найдены';
          case 500:
            return 'Ошибка сервера';
          default:
            return 'Ошибка подключения';
        }
      
      case DioExceptionType.cancel:
        return 'Запрос отменен';
      
      default:
        return 'Ошибка подключения';
    }
  }
  
  // For other error types, simplify the message
  return _simplifyMessage(error.toString());
}

String _simplifyMessage(String message) {
  // Remove technical details
  message = message.replaceAll(RegExp(r'Exception:.*', multiLine: true), '');
  message = message.replaceAll(RegExp(r'Stack trace:.*', multiLine: true), '');
  message = message.replaceAll(RegExp(r'#\d+\s+.*', multiLine: true), '');
  
  // Trim and limit length
  message = message.trim();
  if (message.length > 100) {
    message = message.substring(0, 100);
  }
  
  // If empty after cleanup, return generic message
  if (message.isEmpty) {
    return 'Произошла ошибка';
  }
  
  return message;
}

// Data Sources
final apiDataSourceProvider = Provider<ApiDataSource>((ref) => ApiDataSource());
final localDataSourceProvider = Provider<LocalDataSource>((ref) => LocalDataSource());

// Services
final audioStorageServiceProvider = Provider<AudioStorageService>((ref) {
  return AudioStorageService(Dio());
});

final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService(Dio());
});

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiDataSourceProvider),
    ref.read(localDataSourceProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.read(apiDataSourceProvider),
    ref.read(localDataSourceProvider),
  );
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    ref.read(apiDataSourceProvider),
    ref.read(localDataSourceProvider),
  );
});

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository(
    ref.read(localDataSourceProvider),
  );
});

final statusUpdateQueueRepositoryProvider = Provider((ref) {
  return StatusUpdateQueueRepository(
    ref.read(localDataSourceProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.read(apiDataSourceProvider),
  );
});

final statusSyncServiceProvider = Provider((ref) {
  return StatusSyncService(
    ref.read(statusUpdateQueueRepositoryProvider),
    ref.read(messageRepositoryProvider),
  );
});

final outboxSyncServiceProvider = Provider((ref) {
  return OutboxSyncService(
    ref.read(outboxRepositoryProvider),
    ref.read(messageRepositoryProvider),
  );
});

// Auth State
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(
    ref.read(authRepositoryProvider),
    ref.read(fcmServiceProvider),
    ref,
  );
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final FcmService _fcmService;
  final Ref _ref;

  AuthStateNotifier(this._authRepository, this._fcmService, this._ref) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final isAuth = await _authRepository.isAuthenticated();
      state = state.copyWith(
        isAuthenticated: isAuth,
        isLoading: false,
      );
      
      if (isAuth) {
        print('Auth: User authenticated, token restored');
      } else {
        print('Auth: No valid token found');
      }
    } catch (e) {
      print('Auth: Error checking auth: $e');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  Future<void> register({
    required String phoneNumber,
    required String displayName,
    required String password,
    required String inviteCode,
  }) async {
    // Validate input before sending to server
    if (phoneNumber.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите номер телефона',
      );
      return;
    }
    
    if (displayName.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите имя',
      );
      return;
    }
    
    if (password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите пароль',
      );
      return;
    }
    
    if (password.length < 6) {
      state = state.copyWith(
        isLoading: false,
        error: 'Пароль должен быть не менее 6 символов',
      );
      return;
    }
    
    if (inviteCode.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите код приглашения',
      );
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.register(
        phoneNumber: phoneNumber,
        displayName: displayName,
        password: password,
        inviteCode: inviteCode,
      );
      
      if (response.success) {
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
        );
        
        // Register FCM token after successful registration
        await _registerFcmToken();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
    }
  }

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    // Validate input before sending to server
    if (phoneNumber.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите номер телефона',
      );
      return;
    }
    
    if (password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите пароль',
      );
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _authRepository.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      
      if (response.success) {
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
        );
        
        // Register FCM token after successful login
        await _registerFcmToken();
        
        // Initialize encryption and register public key
        await _initializeEncryption();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      // Initialize FCM service to request permissions and get token
      await _fcmService.initialize();
      print('FCM service initialized after auth');
      
      final token = await _authRepository.getStoredToken();
      
      if (token != null) {
        await _fcmService.registerToken(token);
        print('FCM token registered after auth');
      }
    } catch (e) {
      print('Failed to initialize/register FCM after auth: $e');
      // Don't fail the auth flow if FCM registration fails
    }
  }
  
  Future<void> _initializeEncryption() async {
    try {
      print('[ENCRYPTION] Initializing E2E encryption...');
      
      // Get encryption service
      final encryptionService = _ref.read(encryptionServiceProvider);
      
      // Initialize (load or generate key pair)
      await encryptionService.initialize();
      
      // Get public key and send to server
      final publicKey = await encryptionService.getPublicKeyBase64();
      
      if (publicKey != null) {
        // Update public key on server
        final apiDataSource = _ref.read(apiDataSourceProvider);
        await apiDataSource.updatePublicKey(publicKey);
        print('[ENCRYPTION] Public key registered on server');
      } else {
        print('[ENCRYPTION] Failed to get public key');
      }
    } catch (e) {
      print('[ENCRYPTION] Failed to initialize encryption: $e');
      // Don't fail the auth flow if encryption initialization fails
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    
    // Clear cached user ID on logout
    try {
      final localDataSource = LocalDataSource();
      await localDataSource.clearCurrentUserId();
      print('[Auth] Cleared cached user ID on logout');
    } catch (e) {
      print('[Auth] Failed to clear cached user ID: $e');
    }
    
    state = AuthState();
  }
}


