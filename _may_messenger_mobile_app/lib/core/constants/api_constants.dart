class ApiConstants {
  // Для локальной разработки используем localhost
  // На Windows используйте localhost:5279
  // На Android эмуляторе используйте 10.0.2.2:5279 вместо localhost
  //static const String baseUrl = 'http://localhost:5279';
  //static const String baseUrl = 'http://localhost:7243';
  static const String baseUrl = 'https://messenger.rare-books.ru';
  static const String apiUrl = '$baseUrl/api';
  static const String hubUrl = '$baseUrl/hubs/chat';
  
  // Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String chats = '/chats';
  static const String messages = '/messages';
  static const String audioMessages = '/messages/audio';
  static const String imageMessages = '/messages/image';
  static const String fileMessages = '/messages/file';
}


