/// API Configuration for Rare Books Service
class ApiConfig {
  /// Base URL for the API
  static const String baseUrl = 'https://rare-books.ru/api';
  
  /// Connection timeout in milliseconds
  static const int connectTimeout = 30000;
  
  /// Receive timeout in milliseconds
  static const int receiveTimeout = 30000;
  
  /// Send timeout in milliseconds
  static const int sendTimeout = 30000;
  
  /// API Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authUser = '/auth/user';
  static const String authCaptcha = '/auth/captcha';
  
  static const String books = '/books';
  static const String searchByTitle = '/books/searchByTitle';
  static const String searchByDescription = '/books/searchByDescription';
  static const String searchByPriceRange = '/books/searchByPriceRange';
  static const String searchByCategory = '/books/searchByCategory';
  static const String searchBySeller = '/books/searchBySeller';
  static const String favorites = '/books/favorites';
  static const String recentSales = '/books/recent-sales';
  static const String priceStatistics = '/statistics/prices';
  
  static const String categories = '/categories';
  
  static const String userCollection = '/usercollection';
  
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionCreatePayment = '/subscription/create-payment';
  static const String subscriptionCancel = '/subscription/cancel';
  static const String subscriptionCheckStatus = '/subscription/check-status';
  
  static const String notificationPreferences = '/notification/preferences';
  static const String notificationHistory = '/notification/history';
  static const String notificationTest = '/notification/test';
  static const String telegramConnect = '/notification/telegram/connect';
  static const String telegramDisconnect = '/notification/telegram/disconnect';
  static const String telegramStatus = '/notification/telegram/status';
  static const String telegramGenerateLinkToken = '/notification/telegram/generate-link-token';
  
  static const String userProfile = '/auth/user';
  
  static const String feedback = '/feedback';
  
  /// Get book detail URL
  static String bookDetail(int id) => '/books/$id';
  
  /// Get book images URL
  static String bookImages(int id) => '/books/$id/images';
  
  /// Get book image file URL
  static String bookImageFile(int id, String imageName) => '/books/$id/images/$imageName';
  
  /// Get book thumbnail URL
  static String bookThumbnail(int id, String thumbnailName) => '/books/$id/thumbnails/$thumbnailName';
  
  /// Add/remove book from favorites
  static String bookFavorite(int id) => '/books/$id/favorite';
  
  /// Check if book is favorite
  static String bookIsFavorite(int id) => '/books/$id/is-favorite';
  
  /// Get user profile by ID
  static String userById(int id) => '/user/$id';
  
  /// Get user search history
  static String userSearchHistory(int id) => '/user/$id/searchHistory';
  
  /// Collection book detail
  static String collectionBook(int id) => '/usercollection/$id';
  
  /// Collection book images
  static String collectionBookImages(int id) => '/usercollection/$id/images';
  
  /// Collection statistics
  static String collectionStatistics = '/usercollection/statistics';
  
  /// Collection export PDF
  static String collectionExportPdf = '/usercollection/export/pdf';
  
  /// Collection export JSON
  static String collectionExportJson = '/usercollection/export/json';
  
  /// Notification preference by ID
  static String notificationPreference(int id) => '/notification/preferences/$id';
}

