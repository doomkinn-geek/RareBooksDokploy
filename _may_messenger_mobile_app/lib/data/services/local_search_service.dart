import 'dart:async';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/contact_cache_model.dart';
import '../models/search_result_model.dart';
import '../datasources/local_datasource.dart';

/// High-performance local search service using in-memory caching
/// No network requests - all searches are performed locally for instant results
class LocalSearchService {
  final LocalDataSource _localDataSource;
  
  // In-memory caches for ultra-fast search
  List<Chat>? _cachedChats;
  List<ContactCache>? _cachedContacts;
  Map<String, List<Message>>? _cachedMessages;
  Map<String, String>? _chatTitleMap; // chatId -> title for message results
  
  // Cache timestamps for refresh logic
  DateTime? _chatsLoadedAt;
  DateTime? _contactsLoadedAt;
  DateTime? _messagesLoadedAt;
  
  // Cache validity period (in seconds)
  static const int _cacheValiditySeconds = 60;
  
  LocalSearchService(this._localDataSource);
  
  /// Preload all data into memory for instant search
  /// Call this when app starts or search screen opens
  Future<void> preloadData() async {
    await Future.wait([
      _loadChatsToMemory(),
      _loadContactsToMemory(),
      _loadMessagesToMemory(),
    ]);
    print('[LocalSearch] Data preloaded: ${_cachedChats?.length ?? 0} chats, ${_cachedContacts?.length ?? 0} contacts, ${_cachedMessages?.length ?? 0} chat message sets');
  }
  
  /// Clear in-memory caches (call on logout or memory pressure)
  void clearCache() {
    _cachedChats = null;
    _cachedContacts = null;
    _cachedMessages = null;
    _chatTitleMap = null;
    _chatsLoadedAt = null;
    _contactsLoadedAt = null;
    _messagesLoadedAt = null;
    print('[LocalSearch] Cache cleared');
  }
  
  /// Refresh specific cache
  Future<void> refreshChatsCache() async {
    _cachedChats = null;
    _chatsLoadedAt = null;
    await _loadChatsToMemory();
  }
  
  Future<void> refreshContactsCache() async {
    _cachedContacts = null;
    _contactsLoadedAt = null;
    await _loadContactsToMemory();
  }
  
  Future<void> refreshMessagesCache() async {
    _cachedMessages = null;
    _messagesLoadedAt = null;
    await _loadMessagesToMemory();
  }
  
  // ==================== SEARCH METHODS ====================
  
  /// Search everything locally - contacts, chats, messages
  /// Returns results in under 10ms for typical data sets
  Future<LocalSearchResults> searchAll(String query) async {
    final stopwatch = Stopwatch()..start();
    
    if (query.trim().length < 2) {
      return LocalSearchResults.empty();
    }
    
    final normalizedQuery = _normalizeQuery(query);
    
    // Ensure data is loaded
    await _ensureDataLoaded();
    
    // Search in parallel for maximum speed
    final results = await Future.wait([
      _searchChats(normalizedQuery),
      _searchContacts(normalizedQuery),
      _searchMessages(normalizedQuery),
    ]);
    
    stopwatch.stop();
    print('[LocalSearch] Search completed in ${stopwatch.elapsedMilliseconds}ms for query: "$query"');
    
    return LocalSearchResults(
      chats: results[0] as List<Chat>,
      contacts: results[1] as List<ContactCache>,
      messages: results[2] as List<MessageSearchResult>,
      searchTimeMs: stopwatch.elapsedMilliseconds,
    );
  }
  
  /// Search only chats (groups and private chats)
  Future<List<Chat>> searchChats(String query) async {
    if (query.trim().length < 2) return [];
    await _ensureChatsLoaded();
    return _searchChats(_normalizeQuery(query));
  }
  
  /// Search only contacts
  Future<List<ContactCache>> searchContacts(String query) async {
    if (query.trim().length < 2) return [];
    await _ensureContactsLoaded();
    return _searchContacts(_normalizeQuery(query));
  }
  
  /// Search only messages
  Future<List<MessageSearchResult>> searchMessages(String query) async {
    if (query.trim().length < 2) return [];
    await _ensureMessagesLoaded();
    return _searchMessages(_normalizeQuery(query));
  }
  
  // ==================== INTERNAL SEARCH LOGIC ====================
  
  Future<List<Chat>> _searchChats(String normalizedQuery) async {
    if (_cachedChats == null || _cachedChats!.isEmpty) return [];
    
    final results = <Chat>[];
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    
    for (final chat in _cachedChats!) {
      final titleNormalized = _normalizeText(chat.title);
      
      // Match if all query words are found in title
      bool matches = queryWords.every((word) => titleNormalized.contains(word));
      
      if (matches) {
        results.add(chat);
      }
    }
    
    // Sort: groups first, then by title
    results.sort((a, b) {
      if (a.type == ChatType.group && b.type != ChatType.group) return -1;
      if (a.type != ChatType.group && b.type == ChatType.group) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    
    return results;
  }
  
  Future<List<ContactCache>> _searchContacts(String normalizedQuery) async {
    if (_cachedContacts == null || _cachedContacts!.isEmpty) return [];
    
    final results = <ContactCache>[];
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    
    for (final contact in _cachedContacts!) {
      final nameNormalized = _normalizeText(contact.displayName);
      final phoneNormalized = _normalizeText(contact.phoneNumber ?? '');
      
      // Match if all query words are found in name or phone
      bool matches = queryWords.every((word) => 
        nameNormalized.contains(word) || phoneNormalized.contains(word)
      );
      
      if (matches) {
        results.add(contact);
      }
    }
    
    // Sort by name
    results.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    return results;
  }
  
  Future<List<MessageSearchResult>> _searchMessages(String normalizedQuery) async {
    if (_cachedMessages == null || _cachedMessages!.isEmpty) return [];
    
    final results = <MessageSearchResult>[];
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
    
    // Search through all messages in all chats
    for (final entry in _cachedMessages!.entries) {
      final chatId = entry.key;
      final messages = entry.value;
      final chatTitle = _chatTitleMap?[chatId] ?? 'Чат';
      
      for (final message in messages) {
        // Only search text messages
        if (message.type != MessageType.text || message.content == null) continue;
        if (message.content!.isEmpty) continue;
        
        final contentNormalized = _normalizeText(message.content!);
        
        // Match if all query words are found in content
        bool matches = queryWords.every((word) => contentNormalized.contains(word));
        
        if (matches) {
          results.add(MessageSearchResult(
            messageId: message.id,
            chatId: chatId,
            chatTitle: chatTitle,
            messageContent: message.content!,
            senderName: message.senderName,
            createdAt: message.createdAt,
          ));
        }
      }
    }
    
    // Sort by date descending (newest first)
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Limit results to avoid UI performance issues
    if (results.length > 100) {
      return results.take(100).toList();
    }
    
    return results;
  }
  
  // ==================== DATA LOADING ====================
  
  Future<void> _ensureDataLoaded() async {
    await Future.wait([
      _ensureChatsLoaded(),
      _ensureContactsLoaded(),
      _ensureMessagesLoaded(),
    ]);
  }
  
  Future<void> _ensureChatsLoaded() async {
    if (_cachedChats != null && !_isCacheExpired(_chatsLoadedAt)) return;
    await _loadChatsToMemory();
  }
  
  Future<void> _ensureContactsLoaded() async {
    if (_cachedContacts != null && !_isCacheExpired(_contactsLoadedAt)) return;
    await _loadContactsToMemory();
  }
  
  Future<void> _ensureMessagesLoaded() async {
    if (_cachedMessages != null && !_isCacheExpired(_messagesLoadedAt)) return;
    await _loadMessagesToMemory();
  }
  
  bool _isCacheExpired(DateTime? loadedAt) {
    if (loadedAt == null) return true;
    return DateTime.now().difference(loadedAt).inSeconds > _cacheValiditySeconds;
  }
  
  Future<void> _loadChatsToMemory() async {
    try {
      _cachedChats = await _localDataSource.getCachedChats() ?? [];
      _chatsLoadedAt = DateTime.now();
      
      // Build chat title map for message search results
      _chatTitleMap = {
        for (var chat in _cachedChats!) chat.id: chat.title
      };
      
      print('[LocalSearch] Loaded ${_cachedChats!.length} chats to memory');
    } catch (e) {
      print('[LocalSearch] Failed to load chats: $e');
      _cachedChats = [];
    }
  }
  
  Future<void> _loadContactsToMemory() async {
    try {
      _cachedContacts = await _localDataSource.getContactsCache() ?? [];
      _contactsLoadedAt = DateTime.now();
      print('[LocalSearch] Loaded ${_cachedContacts!.length} contacts to memory');
    } catch (e) {
      print('[LocalSearch] Failed to load contacts: $e');
      _cachedContacts = [];
    }
  }
  
  Future<void> _loadMessagesToMemory() async {
    try {
      _cachedMessages = {};
      
      // First, we need to know which chats exist
      await _ensureChatsLoaded();
      
      if (_cachedChats == null || _cachedChats!.isEmpty) {
        print('[LocalSearch] No chats found, skipping message load');
        _messagesLoadedAt = DateTime.now();
        return;
      }
      
      // Load messages for each chat
      for (final chat in _cachedChats!) {
        final messages = await _localDataSource.getCachedMessages(chat.id);
        if (messages != null && messages.isNotEmpty) {
          _cachedMessages![chat.id] = messages;
        }
      }
      
      _messagesLoadedAt = DateTime.now();
      
      int totalMessages = 0;
      for (var msgs in _cachedMessages!.values) {
        totalMessages += msgs.length;
      }
      print('[LocalSearch] Loaded $totalMessages messages from ${_cachedMessages!.length} chats to memory');
    } catch (e) {
      print('[LocalSearch] Failed to load messages: $e');
      _cachedMessages = {};
    }
  }
  
  // ==================== TEXT NORMALIZATION ====================
  
  /// Normalize query for consistent matching
  String _normalizeQuery(String query) {
    return _normalizeText(query.trim());
  }
  
  /// Normalize text for search comparison
  /// - Converts to lowercase
  /// - Removes extra whitespace
  /// - Handles Cyrillic and Latin characters
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Search results container
class LocalSearchResults {
  final List<Chat> chats;
  final List<ContactCache> contacts;
  final List<MessageSearchResult> messages;
  final int searchTimeMs;
  
  LocalSearchResults({
    required this.chats,
    required this.contacts,
    required this.messages,
    required this.searchTimeMs,
  });
  
  factory LocalSearchResults.empty() => LocalSearchResults(
    chats: [],
    contacts: [],
    messages: [],
    searchTimeMs: 0,
  );
  
  bool get isEmpty => chats.isEmpty && contacts.isEmpty && messages.isEmpty;
  bool get isNotEmpty => !isEmpty;
  
  int get totalCount => chats.length + contacts.length + messages.length;
}

