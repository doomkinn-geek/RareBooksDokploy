import '../datasources/api_datasource.dart';
import '../datasources/local_datasource.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Result class for offline-first chat loading
class ChatsResult {
  final List<Chat> chats;
  final bool isFromCache;
  final bool hasSyncError;
  final String? syncError;

  ChatsResult({
    required this.chats,
    this.isFromCache = false,
    this.hasSyncError = false,
    this.syncError,
  });
}

class ChatRepository {
  final ApiDataSource _apiDataSource;
  final LocalDataSource _localDataSource;
  
  // Background sync callback
  void Function(List<Chat>)? onBackgroundSyncComplete;

  ChatRepository(this._apiDataSource, this._localDataSource);

  /// Offline-first: Returns cached data immediately, syncs in background
  Future<ChatsResult> getChatsOfflineFirst() async {
    List<Chat>? cachedChats;
    
    // 1. Try to get cached data first
    try {
      cachedChats = await _localDataSource.getCachedChats();
      print('[ChatRepository] Loaded ${cachedChats?.length ?? 0} chats from cache');
    } catch (e) {
      print('[ChatRepository] Failed to load from cache: $e');
    }
    
    // 2. If we have cached data, return it immediately and sync in background
    if (cachedChats != null && cachedChats.isNotEmpty) {
      // Start background sync
      _syncChatsInBackground();
      return ChatsResult(chats: cachedChats, isFromCache: true);
    }
    
    // 3. No cache - must fetch from server
    try {
      final serverChats = await _apiDataSource.getChats();
      await _localDataSource.cacheChats(serverChats);
      return ChatsResult(chats: serverChats, isFromCache: false);
    } catch (e) {
      // If we have stale cache, return it with error flag
      if (cachedChats != null) {
        return ChatsResult(
          chats: cachedChats,
          isFromCache: true,
          hasSyncError: true,
          syncError: e.toString(),
        );
      }
      rethrow;
    }
  }
  
  /// Background sync - fetches from server and updates cache
  Future<void> _syncChatsInBackground() async {
    try {
      print('[ChatRepository] Starting background sync...');
      final serverChats = await _apiDataSource.getChats();
      await _localDataSource.cacheChats(serverChats);
      print('[ChatRepository] Background sync completed: ${serverChats.length} chats');
      
      // Notify listeners about sync completion
      if (onBackgroundSyncComplete != null) {
        onBackgroundSyncComplete!(serverChats);
      }
    } catch (e) {
      print('[ChatRepository] Background sync failed: $e');
      // Don't throw - this is background, user already has cached data
    }
  }

  Future<List<Chat>> getChats({bool forceRefresh = false}) async {
    List<Chat>? cachedChats;
    
    // Always try to get cached data first (offline-first approach)
    try {
      cachedChats = await _localDataSource.getCachedChats();
      print('[ChatRepository] Cached chats: ${cachedChats?.length ?? 0}');
    } catch (e) {
      print('[ChatRepository] Failed to load from cache: $e');
    }
    
    if (forceRefresh) {
      // Try to fetch from server, but fallback to cache on error
      try {
        final serverChats = await _apiDataSource.getChats();
        await _localDataSource.cacheChats(serverChats);
        return serverChats;
      } catch (e) {
        print('[ChatRepository] API fetch failed: $e');
        // Return cached data if available
        if (cachedChats != null && cachedChats.isNotEmpty) {
          print('[ChatRepository] Returning cached data due to API error');
          return cachedChats;
        }
        rethrow;
      }
    }
    
    // Not force refresh - return cache if available
    if (cachedChats != null && cachedChats.isNotEmpty) {
      // Start background sync
      _syncChatsInBackground();
      return cachedChats;
    }
    
    // No cache - must fetch from server
    try {
      final serverChats = await _apiDataSource.getChats();
      await _localDataSource.cacheChats(serverChats);
      return serverChats;
    } catch (e) {
      print('[ChatRepository] Failed to fetch chats: $e');
      rethrow;
    }
  }

  Future<Chat> getChat(String chatId) async {
    return await _apiDataSource.getChat(chatId);
  }

  Future<Chat> createChat({
    required String title,
    required List<String> participantIds,
  }) async {
    return await _apiDataSource.createChat(
      title: title,
      participantIds: participantIds,
    );
  }

  Future<void> deleteChat(String chatId) async {
    await _apiDataSource.deleteChat(chatId);
    // Note: Local cache will be updated via SignalR notification
  }

  Future<void> updateChatLastMessageInCache(String chatId, Message message) async {
    await _localDataSource.updateChatLastMessage(chatId, message);
  }
  
  Future<Chat> createOrGetDirectChat(String targetUserId) async {
    return await _apiDataSource.createOrGetDirectChat(targetUserId);
  }
  
  /// Distribute encrypted group keys to participants
  Future<void> distributeGroupKeys(String chatId, List<Map<String, String>> participantKeys) async {
    await _apiDataSource.distributeGroupKeys(chatId, participantKeys);
  }
}



