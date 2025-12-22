import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/models/search_result_model.dart';
import '../../data/services/search_service.dart';
import '../../data/datasources/local_datasource.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  // Create a new Dio instance with proper configuration
  final dio = Dio(BaseOptions(
    baseUrl: 'https://messenger.rare-books.ru',
    headers: {'Content-Type': 'application/json'},
  ));
  
  // Add interceptor to copy auth token from shared preferences
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
  
  return SearchService(dio);
});

final localDataSourceForSearchProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource();
});

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    ref.read(searchServiceProvider),
    ref.read(localDataSourceForSearchProvider),
  );
});

class SearchState {
  final List<User> userResults;
  final List<MessageSearchResult> messageResults;
  final bool isLoading;
  final String? error;
  final String query;

  SearchState({
    this.userResults = const [],
    this.messageResults = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<User>? userResults,
    List<MessageSearchResult>? messageResults,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      userResults: userResults ?? this.userResults,
      messageResults: messageResults ?? this.messageResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;
  final LocalDataSource _localDataSource;
  Timer? _debounceTimer;

  SearchNotifier(this._searchService, this._localDataSource) : super(SearchState());

  void search(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      state = SearchState();
      return;
    }
    
    if (query.trim().length < 2) {
      state = state.copyWith(
        isLoading: false,
        error: 'Введите минимум 2 символа',
        query: query.trim(),
      );
      return;
    }
    
    // Set loading state immediately
    state = state.copyWith(
      isLoading: true,
      error: null,
      query: query.trim(),
    );
    
    // Search local cache immediately for instant results
    _searchLocalContacts(query.trim());
    
    // Debounce backend search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        // Search backend for contacts (contactsOnly=true)
        final users = await _searchService.searchUsers(query.trim(), contactsOnly: true);
        final messages = await _searchService.searchMessages(query.trim());
        
        state = state.copyWith(
          userResults: users,
          messageResults: messages,
          isLoading: false,
          error: null,
        );
      } catch (e) {
        String errorMessage = 'Ошибка поиска';
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout || 
              e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Сервер не отвечает';
          } else if (e.type == DioExceptionType.unknown) {
            errorMessage = 'Нет подключения к интернету';
          } else {
            errorMessage = 'Ошибка соединения';
          }
        } else {
          errorMessage = e.toString();
        }
        
        state = state.copyWith(
          isLoading: false,
          error: errorMessage,
        );
      }
    });
  }

  Future<void> _searchLocalContacts(String query) async {
    try {
      final cachedContacts = await _localDataSource.searchContactsCache(query);
      if (cachedContacts.isNotEmpty) {
        // Convert ContactCache to User for display
        final users = cachedContacts.map((c) => User(
          id: c.userId,
          displayName: c.displayName,
          phoneNumber: '', // Not needed for search results
          role: UserRole.user,
          isOnline: false,
          lastSeenAt: null,
        )).toList();
        
        // Update state with local results (will be replaced by backend results)
        state = state.copyWith(
          userResults: users.cast<User>(),
          isLoading: true, // Still loading backend results
        );
      }
    } catch (e) {
      print('[Search] Failed to search local contacts: $e');
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    state = SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

