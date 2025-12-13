import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/api_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../core/services/fcm_service.dart';

// Утилита для форматирования ошибок
String _formatError(dynamic error) {
  if (error is DioException) {
    if (error.response?.data != null) {
      // Пытаемся извлечь сообщение из ответа сервера
      final data = error.response!.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
      if (data is Map && data.containsKey('error')) {
        return data['error'];
      }
      if (data is Map && data.containsKey('title')) {
        return data['title'];
      }
      if (data is String) {
        // Если это HTML или длинный текст, обрезаем
        if (data.length > 200 || data.contains('<html')) {
          return 'Ошибка сервера: ${error.response?.statusCode ?? "неизвестная ошибка"}';
        }
        return data;
      }
    }
    
    // Стандартные сообщения для разных типов ошибок
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Время ожидания подключения истекло';
      case DioExceptionType.sendTimeout:
        return 'Время отправки запроса истекло';
      case DioExceptionType.receiveTimeout:
        return 'Время получения ответа истекло';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Неверные данные запроса';
          case 401:
            return 'Неверный логин или пароль';
          case 403:
            return 'Доступ запрещен';
          case 404:
            return 'Ресурс не найден';
          case 500:
            return 'Внутренняя ошибка сервера';
          default:
            return 'Ошибка сервера (код: $statusCode)';
        }
      case DioExceptionType.cancel:
        return 'Запрос отменен';
      case DioExceptionType.connectionError:
        return 'Нет подключения к серверу';
      default:
        return 'Ошибка сети';
    }
  }
  
  // Для других типов ошибок
  final errorString = error.toString();
  
  // Убираем технические детали
  if (errorString.contains('Exception:')) {
    final parts = errorString.split('Exception:');
    if (parts.length > 1) {
      return parts[1].trim();
    }
  }
  
  // Если сообщение слишком длинное, обрезаем
  if (errorString.length > 200) {
    return 'Произошла ошибка при выполнении запроса';
  }
  
  return errorString;
}

// Data Sources
final apiDataSourceProvider = Provider<ApiDataSource>((ref) => ApiDataSource());
final localDataSourceProvider = Provider<LocalDataSource>((ref) => LocalDataSource());

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

// Auth State
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(
    ref.read(authRepositoryProvider),
    ref.read(fcmServiceProvider),
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

  AuthStateNotifier(this._authRepository, this._fcmService) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final isAuth = await _authRepository.isAuthenticated();
    state = state.copyWith(isAuthenticated: isAuth);
  }

  Future<void> register({
    required String phoneNumber,
    required String displayName,
    required String password,
    required String inviteCode,
  }) async {
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
      final token = await _authRepository.getStoredToken();
      
      if (token != null) {
        await _fcmService.registerToken(token);
        print('FCM token registered after auth');
      }
    } catch (e) {
      print('Failed to register FCM token after auth: $e');
      // Don't fail the auth flow if FCM registration fails
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = AuthState();
  }
}


