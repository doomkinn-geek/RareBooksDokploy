import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/search_result_model.dart';
import '../../data/services/search_service.dart';
import '../../data/datasources/local_datasource.dart';
import 'chats_provider.dart';

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
    ref,
  );
});

class SearchState {
  final List<User> userResults;
  final List<MessageSearchResult> messageResults;
  final List<Chat> chatResults; // Chats and groups matching the query
  final bool isLoading;
  final String? error;
  final String query;

  SearchState({
    this.userResults = const [],
    this.messageResults = const [],
    this.chatResults = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    List<User>? userResults,
    List<MessageSearchResult>? messageResults,
    List<Chat>? chatResults,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SearchState(
      userResults: userResults ?? this.userResults,
      messageResults: messageResults ?? this.messageResults,
      chatResults: chatResults ?? this.chatResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;
  final LocalDataSource _localDataSource;
  final Ref _ref;
  Timer? _debounceTimer;

  SearchNotifier(this._searchService, this._localDataSource, this._ref) : super(SearchState());

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
    
    // Search chats/groups locally (instant)
    _searchLocalChats(query.trim());
    
    // Debounce backend search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        // Get current local contacts results first
        final localContacts = state.userResults;
        
        // Search backend for messages only
        // Contacts search is done locally from phone book cache
        final messages = await _searchService.searchMessages(query.trim());
        
        // Keep local contacts, only update messages
        state = state.copyWith(
          userResults: localContacts, // Keep local contacts from phone book
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
        
        // Keep local results even on error
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
        // Use phone number from cache for display in search results
        final users = cachedContacts.map((c) => User(
          id: c.userId,
          displayName: c.displayName,
          phoneNumber: c.phoneNumber ?? '', // Use cached phone number
          role: UserRole.user,
          isOnline: false,
          lastSeenAt: null,
        )).toList();
        
        // Update state with local results (kept for contacts, not replaced by backend)
        state = state.copyWith(
          userResults: users.cast<User>(),
          isLoading: true, // Still loading backend results
        );
      }
    } catch (e) {
      print('[Search] Failed to search local contacts: $e');
    }
  }

  /// Search chats and groups locally by title
  void _searchLocalChats(String query) {
    try {
      final chatsState = _ref.read(chatsProvider);
      final queryLower = query.toLowerCase();
      
      // Filter chats by title matching the query
      final matchingChats = chatsState.chats.where((chat) {
        return chat.title.toLowerCase().contains(queryLower);
      }).toList();
      
      // Sort groups first, then private chats
      matchingChats.sort((a, b) {
        if (a.type == ChatType.group && b.type != ChatType.group) return -1;
        if (a.type != ChatType.group && b.type == ChatType.group) return 1;
        return a.title.compareTo(b.title);
      });
      
      state = state.copyWith(
        chatResults: matchingChats,
        isLoading: true, // Still loading backend results
      );
    } catch (e) {
      print('[Search] Failed to search local chats: $e');
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

