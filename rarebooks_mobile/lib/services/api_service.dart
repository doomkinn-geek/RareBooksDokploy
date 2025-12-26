import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// API Service for communicating with the Rare Books backend
class ApiService {
  late final Dio _dio;
  final StorageService _storageService;
  
  ApiService({required StorageService storageService})
      : _storageService = storageService {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      sendTimeout: const Duration(milliseconds: ApiConfig.sendTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) {
        // Accept all status codes to handle them manually
        return status != null && status < 500;
      },
    ));
    
    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available
        final token = await _storageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        developer.log(
          'API Request: ${options.method} ${options.baseUrl}${options.path}',
          name: 'ApiService',
        );
        return handler.next(options);
      },
      onResponse: (response, handler) {
        developer.log(
          'API Response: ${response.statusCode} ${response.requestOptions.path}',
          name: 'ApiService',
        );
        return handler.next(response);
      },
      onError: (error, handler) {
        developer.log(
          'API Error: ${error.type} ${error.message}',
          name: 'ApiService',
          error: error,
        );
        
        // Handle common errors
        if (error.response?.statusCode == 401) {
          // Token expired or invalid - could trigger logout
          _storageService.clearUserData();
        }
        return handler.next(error);
      },
    ));
  }
  
  // ==================== Authentication ====================
  
  /// Login user
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        ApiConfig.authLogin,
        data: request.toJson(),
      );
      
      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      } else if (response.statusCode == 401) {
        throw Exception('Неверный email или пароль');
      } else if (response.statusCode == 400) {
        throw Exception('Некорректные данные для входа');
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } on DioException catch (e) {
      developer.log(
        'Login error: ${e.type} - ${e.message}',
        name: 'ApiService',
        error: e,
      );
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Превышено время ожидания. Проверьте подключение к интернету');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Не удалось подключиться к серверу. Проверьте подключение к интернету');
      } else if (e.type == DioExceptionType.badCertificate) {
        throw Exception('Ошибка сертификата безопасности');
      } else if (e.response != null) {
        if (e.response!.statusCode == 401) {
          throw Exception('Неверный email или пароль');
        } else if (e.response!.statusCode == 400) {
          throw Exception('Некорректные данные для входа');
        } else {
          throw Exception('Ошибка сервера: ${e.response!.statusCode}');
        }
      } else {
        throw Exception('Ошибка соединения: ${e.message}');
      }
    } catch (e) {
      developer.log(
        'Unexpected login error: $e',
        name: 'ApiService',
        error: e,
      );
      throw Exception('Ошибка соединения. Проверьте интернет-подключение');
    }
  }
  
  /// Register new user
  Future<void> register(RegisterRequest request) async {
    await _dio.post(
      ApiConfig.authRegister,
      data: request.toJson(),
    );
  }
  
  /// Get current user
  Future<User> getCurrentUser() async {
    final response = await _dio.get(ApiConfig.authUser);
    return User.fromJson(response.data);
  }
  
  /// Get captcha image
  Future<Uint8List> getCaptcha() async {
    final response = await _dio.get(
      ApiConfig.authCaptcha,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }
  
  // ==================== Books ====================
  
  /// Search books by title
  Future<BookSearchResponse> searchByTitle({
    required String title,
    bool exactPhrase = false,
    int page = 1,
    int pageSize = 10,
    List<int>? categoryIds,
  }) async {
    final params = <String, dynamic>{
      'title': title,
      'exactPhrase': exactPhrase,
      'page': page,
      'pageSize': pageSize,
    };
    
    if (categoryIds != null && categoryIds.isNotEmpty) {
      for (var i = 0; i < categoryIds.length; i++) {
        params['categoryIds[$i]'] = categoryIds[i];
      }
    }
    
    final response = await _dio.get(
      ApiConfig.searchByTitle,
      queryParameters: params,
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Search books by description
  Future<BookSearchResponse> searchByDescription({
    required String description,
    bool exactPhrase = false,
    int page = 1,
    int pageSize = 10,
    List<int>? categoryIds,
  }) async {
    final params = <String, dynamic>{
      'description': description,
      'exactPhrase': exactPhrase,
      'page': page,
      'pageSize': pageSize,
    };
    
    if (categoryIds != null && categoryIds.isNotEmpty) {
      for (var i = 0; i < categoryIds.length; i++) {
        params['categoryIds[$i]'] = categoryIds[i];
      }
    }
    
    final response = await _dio.get(
      ApiConfig.searchByDescription,
      queryParameters: params,
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Search books by price range
  Future<BookSearchResponse> searchByPriceRange({
    required double minPrice,
    required double maxPrice,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      ApiConfig.searchByPriceRange,
      queryParameters: {
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Search books by category
  Future<BookSearchResponse> searchByCategory({
    required int categoryId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      ApiConfig.searchByCategory,
      queryParameters: {
        'categoryId': categoryId,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Search books by seller
  Future<BookSearchResponse> searchBySeller({
    required String sellerName,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      ApiConfig.searchBySeller,
      queryParameters: {
        'sellerName': sellerName,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Get book by ID
  Future<Book> getBook(int id) async {
    final response = await _dio.get(ApiConfig.bookDetail(id));
    return Book.fromJson(response.data);
  }
  
  /// Get book images
  Future<BookImagesResponse> getBookImages(int id) async {
    final response = await _dio.get(ApiConfig.bookImages(id));
    return BookImagesResponse.fromJson(response.data);
  }
  
  /// Get book image file as bytes
  Future<Uint8List> getBookImageFile(int bookId, String imageName) async {
    final response = await _dio.get(
      ApiConfig.bookImageFile(bookId, imageName),
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data;
  }
  
  /// Get recent sales
  Future<List<RecentSale>> getRecentSales({int limit = 5}) async {
    final response = await _dio.get(
      ApiConfig.recentSales,
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((json) => RecentSale.fromJson(json))
        .toList();
  }
  
  /// Get price statistics
  Future<PriceStatistics> getPriceStatistics({int? categoryId}) async {
    final params = <String, dynamic>{};
    if (categoryId != null) {
      params['categoryId'] = categoryId;
    }
    
    final response = await _dio.get(
      ApiConfig.priceStatistics,
      queryParameters: params,
    );
    return PriceStatistics.fromJson(response.data);
  }
  
  // ==================== Favorites ====================
  
  /// Get favorite books
  Future<BookSearchResponse> getFavorites({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      ApiConfig.favorites,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );
    return BookSearchResponse.fromJson(response.data);
  }
  
  /// Add book to favorites
  Future<void> addToFavorites(int bookId) async {
    await _dio.post(ApiConfig.bookFavorite(bookId));
  }
  
  /// Remove book from favorites
  Future<void> removeFromFavorites(int bookId) async {
    await _dio.delete(ApiConfig.bookFavorite(bookId));
  }
  
  /// Check if book is favorite
  Future<bool> isBookFavorite(int bookId) async {
    final response = await _dio.get(ApiConfig.bookIsFavorite(bookId));
    return response.data as bool;
  }
  
  // ==================== Categories ====================
  
  /// Get all categories
  Future<List<Category>> getCategories() async {
    final response = await _dio.get(ApiConfig.categories);
    return (response.data as List)
        .map((json) => Category.fromJson(json))
        .toList();
  }
  
  // ==================== User Collection ====================
  
  /// Get user collection
  Future<List<CollectionBook>> getCollection() async {
    final response = await _dio.get(ApiConfig.userCollection);
    return (response.data as List)
        .map((json) => CollectionBook.fromJson(json))
        .toList();
  }
  
  /// Get collection statistics
  Future<CollectionStatistics> getCollectionStatistics() async {
    final response = await _dio.get(ApiConfig.collectionStatistics);
    return CollectionStatistics.fromJson(response.data);
  }
  
  /// Add book to collection
  Future<CollectionBook> addToCollection(CollectionBookRequest request) async {
    final response = await _dio.post(
      ApiConfig.userCollection,
      data: request.toJson(),
    );
    return CollectionBook.fromJson(response.data);
  }
  
  /// Update collection book
  Future<CollectionBook> updateCollectionBook(
    int id,
    CollectionBookRequest request,
  ) async {
    final response = await _dio.put(
      ApiConfig.collectionBook(id),
      data: request.toJson(),
    );
    return CollectionBook.fromJson(response.data);
  }
  
  /// Delete collection book
  Future<void> deleteCollectionBook(int id) async {
    await _dio.delete(ApiConfig.collectionBook(id));
  }
  
  /// Upload collection book image
  Future<void> uploadCollectionBookImage(int bookId, Uint8List imageData, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageData, filename: fileName),
    });
    
    await _dio.post(
      ApiConfig.collectionBookImages(bookId),
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }
  
  /// Get collection book matches (similar books)
  Future<List<CollectionBookMatch>> getCollectionBookMatches(int bookId) async {
    final response = await _dio.get('${ApiConfig.collectionBook(bookId)}/matches');
    return (response.data as List)
        .map((json) => CollectionBookMatch.fromJson(json))
        .toList();
  }
  
  // ==================== Subscription ====================
  
  /// Get subscription plans
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final response = await _dio.get(ApiConfig.subscriptionPlans);
    return (response.data as List)
        .map((json) => SubscriptionPlan.fromJson(json))
        .toList();
  }
  
  /// Create payment
  Future<CreatePaymentResponse> createPayment(CreatePaymentRequest request) async {
    final response = await _dio.post(
      ApiConfig.subscriptionCreatePayment,
      data: request.toJson(),
    );
    return CreatePaymentResponse.fromJson(response.data);
  }
  
  /// Cancel subscription
  Future<void> cancelSubscription() async {
    await _dio.post(ApiConfig.subscriptionCancel);
  }
  
  /// Check subscription status
  Future<SubscriptionStatus> checkSubscriptionStatus() async {
    final response = await _dio.get(ApiConfig.subscriptionCheckStatus);
    return SubscriptionStatus.fromJson(response.data);
  }
  
  // ==================== Notifications ====================
  
  /// Get notification preferences
  Future<List<NotificationPreference>> getNotificationPreferences() async {
    final response = await _dio.get(ApiConfig.notificationPreferences);
    return (response.data as List)
        .map((json) => NotificationPreference.fromJson(json))
        .toList();
  }
  
  /// Create notification preference
  Future<NotificationPreference> createNotificationPreference(
    NotificationPreferenceRequest request,
  ) async {
    final response = await _dio.post(
      ApiConfig.notificationPreferences,
      data: request.toJson(),
    );
    return NotificationPreference.fromJson(response.data);
  }
  
  /// Update notification preference
  Future<NotificationPreference> updateNotificationPreference(
    int id,
    NotificationPreferenceRequest request,
  ) async {
    final response = await _dio.put(
      ApiConfig.notificationPreference(id),
      data: request.toJson(),
    );
    return NotificationPreference.fromJson(response.data);
  }
  
  /// Delete notification preference
  Future<void> deleteNotificationPreference(int id) async {
    await _dio.delete(ApiConfig.notificationPreference(id));
  }
  
  /// Get notification history
  Future<List<NotificationHistoryItem>> getNotificationHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      ApiConfig.notificationHistory,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (response.data as List)
        .map((json) => NotificationHistoryItem.fromJson(json))
        .toList();
  }
  
  /// Get Telegram status
  Future<TelegramStatus> getTelegramStatus() async {
    final response = await _dio.get(ApiConfig.telegramStatus);
    return TelegramStatus.fromJson(response.data);
  }
  
  /// Connect Telegram
  Future<void> connectTelegram(ConnectTelegramRequest request) async {
    await _dio.post(
      ApiConfig.telegramConnect,
      data: request.toJson(),
    );
  }
  
  /// Disconnect Telegram
  Future<void> disconnectTelegram() async {
    await _dio.post(ApiConfig.telegramDisconnect);
  }
  
  // ==================== User Profile ====================
  
  /// Get user profile
  Future<User> getUserProfile(int userId) async {
    final response = await _dio.get(ApiConfig.userById(userId));
    return User.fromJson(response.data);
  }
  
  /// Get current user profile
  Future<User> getMyProfile() async {
    final response = await _dio.get(ApiConfig.userProfile);
    return User.fromJson(response.data);
  }
  
  // ==================== Feedback ====================
  
  /// Send feedback
  Future<void> sendFeedback(String text) async {
    await _dio.post(
      ApiConfig.feedback,
      data: {'text': text},
    );
  }
}

