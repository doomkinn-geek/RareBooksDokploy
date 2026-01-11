import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/search_result_model.dart';
import '../../data/services/local_search_service.dart';
import '../../data/datasources/local_datasource.dart';

/// Provider for LocalDataSource (shared instance)
final localDataSourceForSearchProvider = Provider<LocalDataSource>((ref) {
  return LocalDataSource();
});

/// Provider for LocalSearchService - the main search engine
final localSearchServiceProvider = Provider<LocalSearchService>((ref) {
  final localDataSource = ref.read(localDataSourceForSearchProvider);
  return LocalSearchService(localDataSource);
});

/// Main search provider - completely local, no network requests
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(
    ref.read(localSearchServiceProvider),
  );
});

class SearchState {
  final List<User> userResults;
  final List<MessageSearchResult> messageResults;
  final List<Chat> chatResults;
  final bool isLoading;
  final String? error;
  final String query;
  final int? searchTimeMs; // Time taken for search in milliseconds

  SearchState({
    this.userResults = const [],
    this.messageResults = const [],
    this.chatResults = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.searchTimeMs,
  });

  SearchState copyWith({
    List<User>? userResults,
    List<MessageSearchResult>? messageResults,
    List<Chat>? chatResults,
    bool? isLoading,
    String? error,
    String? query,
    int? searchTimeMs,
  }) {
    return SearchState(
      userResults: userResults ?? this.userResults,
      messageResults: messageResults ?? this.messageResults,
      chatResults: chatResults ?? this.chatResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      searchTimeMs: searchTimeMs ?? this.searchTimeMs,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final LocalSearchService _searchService;
  Timer? _debounceTimer;
  bool _isPreloaded = false;

  SearchNotifier(this._searchService) : super(SearchState());

  /// Preload search data for instant results
  /// Call this when search screen is opened
  Future<void> preload() async {
    if (_isPreloaded) return;
    
    try {
      await _searchService.preloadData();
      _isPreloaded = true;
    } catch (e) {
      print('[SearchNotifier] Preload failed: $e');
    }
  }

  /// Main search method - completely local, instant results
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
        chatResults: [],
        userResults: [],
        messageResults: [],
      );
      return;
    }
    
    // For local search, use very short debounce (50ms) for snappy UX
    _debounceTimer = Timer(const Duration(milliseconds: 50), () async {
      state = state.copyWith(
        isLoading: true,
        error: null,
        query: query.trim(),
      );
      
      try {
        final results = await _searchService.searchAll(query.trim());
        
        // Convert ContactCache to User for UI compatibility
        final users = results.contacts.map((c) => User(
          id: c.userId,
          displayName: c.displayName,
          phoneNumber: c.phoneNumber ?? '',
          role: UserRole.user,
          isOnline: false,
          lastSeenAt: null,
        )).toList();
        
        state = state.copyWith(
          chatResults: results.chats,
          userResults: users.cast<User>(),
          messageResults: results.messages,
          isLoading: false,
          error: null,
          searchTimeMs: results.searchTimeMs,
        );
        
        print('[SearchNotifier] Found ${results.totalCount} results in ${results.searchTimeMs}ms');
      } catch (e) {
        print('[SearchNotifier] Search error: $e');
        state = state.copyWith(
          isLoading: false,
          error: 'Ошибка поиска: $e',
        );
      }
    });
  }

  /// Refresh all search caches (call when new data is available)
  Future<void> refreshCache() async {
    try {
      await _searchService.preloadData();
      print('[SearchNotifier] Cache refreshed');
      
      // Re-run search if there's an active query
      if (state.query.isNotEmpty) {
        search(state.query);
      }
    } catch (e) {
      print('[SearchNotifier] Failed to refresh cache: $e');
    }
  }

  void clear() {
    _debounceTimer?.cancel();
    state = SearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchService.clearCache();
    super.dispose();
  }
}
