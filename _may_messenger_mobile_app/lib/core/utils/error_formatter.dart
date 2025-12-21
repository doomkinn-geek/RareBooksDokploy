import 'package:dio/dio.dart';

String formatUserFriendlyError(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Сервер не отвечает. Проверьте подключение.';
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return 'Ошибка авторизации. Войдите заново.';
        } else if (statusCode == 403) {
          return 'Доступ запрещен.';
        } else if (statusCode == 404) {
          return 'Ресурс не найден.';
        } else if (statusCode == 500) {
          return 'Ошибка сервера. Попробуйте позже.';
        }
        return 'Ошибка сервера (код $statusCode).';
      
      case DioExceptionType.cancel:
        return 'Запрос отменен.';
      
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException') ||
            error.error.toString().contains('Failed host lookup')) {
          return 'Нет подключения к интернету.';
        }
        return 'Ошибка соединения.';
      
      default:
        return 'Произошла ошибка. Попробуйте еще раз.';
    }
  }
  
  // For non-Dio errors
  final errorString = error.toString().toLowerCase();
  
  if (errorString.contains('socket') || 
      errorString.contains('failed host lookup')) {
    return 'Нет подключения к интернету.';
  }
  
  if (errorString.contains('timeout')) {
    return 'Сервер не отвечает.';
  }
  
  if (errorString.contains('certificate') || 
      errorString.contains('ssl') ||
      errorString.contains('handshake')) {
    return 'Ошибка безопасного соединения.';
  }
  
  // Return a generic error message for unknown errors
  return 'Произошла ошибка. Попробуйте еще раз.';
}

