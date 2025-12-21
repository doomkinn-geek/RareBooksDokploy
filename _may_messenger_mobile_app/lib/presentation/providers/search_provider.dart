import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/search_result_model.dart';
import '../../data/services/search_service.dart';

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

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(searchServiceProvider));
});

class SearchState {
  final List<User> userResults;
  final List<Chat> chatResults;
  final List<MessageSearchResult> messageResults;
  final bool isLoading;
  final String? error;
  final String query;

  SearchState({
    this.userResults = const [],
    this.chatResults = const [],
    this.messageResults = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<User>? userResults,
    List<Chat>? chatResults,
    List<MessageSearchResult>? messageResults,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      userResults: userResults ?? this.userResults,
      chatResults: chatResults ?? this.chatResults,
      messageResults: messageResults ?? this.messageResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;
  Timer? _debounceTimer;

  SearchNotifier(this._searchService) : super(SearchState());

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
    
    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final users = await _searchService.searchUsers(query.trim());
        final chats = await _searchService.searchChats(query.trim());
        final messages = await _searchService.searchMessages(query.trim());
        
        state = state.copyWith(
          userResults: users,
          chatResults: chats,
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

