class ApiConstants {
  // Для локальной разработки используем localhost
  // ВАЖНО: На Android эмуляторе используйте 10.0.2.2 вместо localhost
  static const String baseUrl = 'http://localhost:5000';
  static const String apiUrl = '$baseUrl/api';
  static const String hubUrl = '$baseUrl/hubs/chat';
  
  // Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String chats = '/chats';
  static const String messages = '/messages';
  static const String audioMessages = '/messages/audio';
}

