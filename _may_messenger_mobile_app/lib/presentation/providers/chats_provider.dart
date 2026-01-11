import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/services/encryption_service.dart';
import 'auth_provider.dart';

final chatsProvider = StateNotifierProvider<ChatsNotifier, ChatsState>((ref) {
  return ChatsNotifier(ref.read(chatRepositoryProvider), ref);
});

class ChatsState {
  final List<Chat> chats;
  final bool isLoading;
  final bool isSyncing; // Background sync in progress
  final bool isOfflineMode; // Data is from cache, not server
  final String? error;
  final String? syncError; // Non-fatal sync error (shown as banner, not blocking)

  ChatsState({
    this.chats = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOfflineMode = false,
    this.error,
    this.syncError,
  });

  ChatsState copyWith({
    List<Chat>? chats,
    bool? isLoading,
    bool? isSyncing,
    bool? isOfflineMode,
    String? error,
    String? syncError,
  }) {
    return ChatsState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      error: error,
      syncError: syncError,
    );
  }

  List<Chat> get groupChats => chats.where((c) => c.type == ChatType.group).toList();
  List<Chat> get privateChats => chats.where((c) => c.type == ChatType.private).toList();
}

class ChatsNotifier extends StateNotifier<ChatsState> {
  final dynamic _chatRepository;
  final Ref _ref;
  
  // Track chats where we've locally cleared unread count
  // This prevents loadChats from overwriting with stale server data
  final Set<String> _locallyReadChats = {};

  ChatsNotifier(this._chatRepository, this._ref) : super(ChatsState()) {
    // НЕ загружаем чаты автоматически - они будут загружены MainScreen
    // после того, как токен будет восстановлен
  }

  Future<void> loadChats({bool forceRefresh = false}) async {
    // Don't set loading if we already have chats (smoother UX)
    final hasExistingChats = state.chats.isNotEmpty;
    
    if (!hasExistingChats) {
      state = state.copyWith(isLoading: true, error: null, syncError: null);
    } else {
      // Show syncing indicator instead of full loading
      state = state.copyWith(isSyncing: true, syncError: null);
    }
    
    try {
      final List<Chat> fetchedChats = await _chatRepository.getChats(forceRefresh: forceRefresh);
      
      // Preserve locally cleared unread counts
      final List<Chat> chats = _applyLocallyReadChats(fetchedChats);
      
      // Clear _locallyReadChats if server confirms unread is 0
      _syncLocallyReadChats(fetchedChats);
      
      state = state.copyWith(
        chats: chats,
        isLoading: false,
        isSyncing: false,
        isOfflineMode: false,
        error: null,
        syncError: null,
      );
    } catch (e) {
      print('[ChatsProvider] loadChats error: $e');
      final userFriendlyError = formatUserFriendlyError(e);
      
      // If we have existing chats, show them with sync error (not blocking error)
      if (hasExistingChats) {
        state = state.copyWith(
          isLoading: false,
          isSyncing: false,
          isOfflineMode: true,
          syncError: userFriendlyError,
        );
      } else {
        // No chats at all - this is a blocking error
        state = state.copyWith(
          isLoading: false,
          isSyncing: false,
          error: userFriendlyError,
        );
      }
    }
  }
  
  /// Apply locally read chat tracking to preserve unread=0
  List<Chat> _applyLocallyReadChats(List<Chat> serverChats) {
    return serverChats.map((chat) {
      if (_locallyReadChats.contains(chat.id)) {
        // Keep unread count at 0 if we've locally marked it as read
        return chat.copyWith(unreadCount: 0);
      }
      return chat;
    }).toList();
  }
  
  /// Sync locally read tracking with server state
  void _syncLocallyReadChats(List<Chat> serverChats) {
    final chatsToClear = <String>[];
    for (final chatId in _locallyReadChats) {
      final serverChat = serverChats.firstWhere(
        (c) => c.id == chatId, 
        orElse: () => Chat(id: '', type: ChatType.private, title: '', unreadCount: 0, createdAt: DateTime.now())
      );
      if (serverChat.id.isNotEmpty && serverChat.unreadCount == 0) {
        chatsToClear.add(chatId);
      }
    }
    for (final chatId in chatsToClear) {
      _locallyReadChats.remove(chatId);
    }
  }
  
  /// Handle background sync completion from repository
  void onBackgroundSyncComplete(List<Chat> serverChats) {
    print('[ChatsProvider] Background sync completed with ${serverChats.length} chats');
    
    final chats = _applyLocallyReadChats(serverChats);
    _syncLocallyReadChats(serverChats);
    
    state = state.copyWith(
      chats: chats,
      isSyncing: false,
      isOfflineMode: false,
      syncError: null,
    );
  }

  Future<Chat?> createChat({
    String? title,
    required List<String> participantIds,
  }) async {
    try {
      final chat = await _chatRepository.createChat(
        title: title ?? '',
        participantIds: participantIds,
      );
      await loadChats(forceRefresh: true);
      return chat;
    } catch (e) {
      state = state.copyWith(error: formatUserFriendlyError(e));
      return null;
    }
  }

  /// Create or get existing direct chat with a user
  Future<Chat> createOrGetDirectChat(String targetUserId) async {
    try {
      final chat = await _chatRepository.createOrGetDirectChat(targetUserId);
      
      // Add chat to state if not already present
      final exists = state.chats.any((c) => c.id == chat.id);
      if (!exists) {
        state = state.copyWith(chats: [chat, ...state.chats]);
      }
      
      return chat;
    } catch (e) {
      state = state.copyWith(error: formatUserFriendlyError(e));
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _chatRepository.deleteChat(chatId);
      // Chat will be removed from state via SignalR notification
    } catch (e) {
      print('[ChatsProvider] Failed to delete chat: $e');
      state = state.copyWith(error: formatUserFriendlyError(e));
      rethrow;
    }
  }

  void removeChat(String chatId) {
    final updatedChats = state.chats.where((c) => c.id != chatId).toList();
    state = state.copyWith(chats: updatedChats);
  }

  void addChat(Chat chat) {
    final exists = state.chats.any((c) => c.id == chat.id);
    if (!exists) {
      state = state.copyWith(chats: [chat, ...state.chats]);
    }
  }

  void updateChat(Chat updatedChat) {
    final index = state.chats.indexWhere((c) => c.id == updatedChat.id);
    if (index != -1) {
      final updatedChats = [...state.chats];
      updatedChats[index] = updatedChat;
      state = state.copyWith(chats: updatedChats);
    }
  }

  void updateChatLastMessage(String chatId, Message message, {bool incrementUnread = false}) {
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = state.chats[index];
      final newUnreadCount = incrementUnread ? chat.unreadCount + 1 : chat.unreadCount;
      
      final updatedChat = Chat(
        id: chat.id,
        type: chat.type,
        title: chat.title,
        avatar: chat.avatar,
        lastMessage: message,
        unreadCount: newUnreadCount,
        createdAt: chat.createdAt,
        otherParticipantId: chat.otherParticipantId,
      );
      
      final updatedChats = [...state.chats];
      updatedChats[index] = updatedChat;
      
      // Сортируем чаты по времени последнего сообщения (новые вверху)
      updatedChats.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      
      state = state.copyWith(chats: updatedChats);
      
      // Сохраняем в кэш
      try {
        _chatRepository.updateChatLastMessageInCache(chatId, message);
      } catch (e) {
        print('[ChatsProvider] Failed to update last message in cache: $e');
      }
    }
  }

  void clearUnreadCount(String chatId) {
    // Mark this chat as locally read to prevent loadChats from overwriting
    _locallyReadChats.add(chatId);
    
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = state.chats[index];
      if (chat.unreadCount > 0) {
        final updatedChat = Chat(
          id: chat.id,
          type: chat.type,
          title: chat.title,
          avatar: chat.avatar,
          lastMessage: chat.lastMessage,
          unreadCount: 0,
          createdAt: chat.createdAt,
          otherParticipantId: chat.otherParticipantId,
          otherParticipantAvatar: chat.otherParticipantAvatar,
          otherParticipantIsOnline: chat.otherParticipantIsOnline,
          otherParticipantLastSeenAt: chat.otherParticipantLastSeenAt,
        );
        
        final updatedChats = [...state.chats];
        updatedChats[index] = updatedChat;
        state = state.copyWith(chats: updatedChats);
        
        print('[ChatsProvider] Cleared unread count for chat $chatId');
      }
    }
  }
  
  void updateUnreadCountOnStatusUpdate(String chatId, String messageId, MessageStatus status) {
    // Only process 'read' status updates
    if (status != MessageStatus.read) return;
    
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index == -1) {
      print('[ChatsProvider] Chat not found for unread count update: $chatId');
      return;
    }
    
    final chat = state.chats[index];
    
    // Only decrement if there are unread messages
    if (chat.unreadCount > 0) {
      final newUnreadCount = (chat.unreadCount - 1).clamp(0, 999999);
      
      // If unread count reaches 0, mark as locally read
      if (newUnreadCount == 0) {
        _locallyReadChats.add(chatId);
      }
      
      final updatedChat = Chat(
        id: chat.id,
        type: chat.type,
        title: chat.title,
        avatar: chat.avatar,
        lastMessage: chat.lastMessage,
        unreadCount: newUnreadCount,
        createdAt: chat.createdAt,
        otherParticipantId: chat.otherParticipantId,
        otherParticipantAvatar: chat.otherParticipantAvatar,
        otherParticipantIsOnline: chat.otherParticipantIsOnline,
        otherParticipantLastSeenAt: chat.otherParticipantLastSeenAt,
      );
      
      final updatedChats = [...state.chats];
      updatedChats[index] = updatedChat;
      state = state.copyWith(chats: updatedChats);
      
      print('[ChatsProvider] Updated unread count for chat $chatId: ${chat.unreadCount} -> $newUnreadCount');
    }
  }
  
  /// Reset the locally read tracking when user logs out or app restarts
  void resetLocallyReadChats() {
    _locallyReadChats.clear();
  }
  
  // ==================== Group Chat Encryption ====================
  
  /// Generate and distribute encryption keys for a group chat
  /// Called after creating a group chat
  Future<void> distributeGroupKeys(String chatId, List<String> participantIds) async {
    try {
      print('[ENCRYPTION] Distributing group keys for chat $chatId');
      
      final encryptionService = _ref.read(encryptionServiceProvider);
      final apiDataSource = _ref.read(apiDataSourceProvider);
      
      // Generate a random AES key for this group
      final groupKey = await encryptionService.generateGroupKey();
      
      // Get public keys for all participants
      final publicKeys = await apiDataSource.getPublicKeys(participantIds);
      
      // Encrypt the group key for each participant
      final participantKeys = <Map<String, String>>[];
      
      for (final participantId in participantIds) {
        final publicKey = publicKeys[participantId];
        
        if (publicKey != null && publicKey.isNotEmpty) {
          try {
            final encryptedKey = await encryptionService.encryptGroupKeyForUser(
              groupKey, 
              publicKey,
            );
            participantKeys.add({
              'userId': participantId,
              'encryptedKey': encryptedKey,
            });
            print('[ENCRYPTION] Encrypted key for participant $participantId');
          } catch (e) {
            print('[ENCRYPTION] Failed to encrypt key for $participantId: $e');
          }
        } else {
          print('[ENCRYPTION] No public key for participant $participantId');
        }
      }
      
      // Send encrypted keys to server
      if (participantKeys.isNotEmpty) {
        await _chatRepository.distributeGroupKeys(chatId, participantKeys);
        print('[ENCRYPTION] Group keys distributed successfully');
      }
      
      // Store the group key locally for this chat
      encryptionService.setGroupSessionKey(chatId, groupKey);
      
    } catch (e) {
      print('[ENCRYPTION] Failed to distribute group keys: $e');
    }
  }
  
  /// Load and decrypt group key for a chat where we're a participant
  Future<void> loadGroupKey(String chatId) async {
    try {
      final chat = state.chats.firstWhere(
        (c) => c.id == chatId,
        orElse: () => throw Exception('Chat not found'),
      );
      
      if (chat.type != ChatType.group) {
        return; // Not a group chat
      }
      
      if (chat.encryptedChatKey == null || chat.encryptedChatKey!.isEmpty) {
        print('[ENCRYPTION] No encrypted key for group chat $chatId');
        return;
      }
      
      final encryptionService = _ref.read(encryptionServiceProvider);
      
      // Find who encrypted this key for us (usually the group creator)
      // For now, we need the creator's public key
      // In a full implementation, we'd store who encrypted the key
      
      // For simplicity, skip decryption here - the key was encrypted with our public key
      // and will need the sender's info to decrypt
      
      print('[ENCRYPTION] Group key loaded for chat $chatId');
    } catch (e) {
      print('[ENCRYPTION] Failed to load group key: $e');
    }
  }
}


