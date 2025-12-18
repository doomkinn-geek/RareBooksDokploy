import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../data/services/message_sync_service.dart';
import '../../data/repositories/message_cache_repository.dart';
import 'auth_provider.dart';
import 'signalr_provider.dart';
import 'profile_provider.dart';

// LRU Cache provider - singleton для всего приложения
final messageCacheProvider = Provider<MessageCacheRepository>((ref) {
  return MessageCacheRepository();
});

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    // Keep the provider alive even when not used
    ref.keepAlive();
    return MessagesNotifier(
      ref.read(messageRepositoryProvider),
      ref.read(outboxRepositoryProvider),
      chatId,
      ref.read(signalRServiceProvider),
      ref.read(messageCacheProvider),
      ref,
    );
  },
);

class MessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final dynamic _messageRepository;
  final dynamic _outboxRepository;
  final String chatId;
  final dynamic _signalRService;
  final MessageCacheRepository _cache;
  final Ref _ref;
  final _uuid = const Uuid();
  late final MessageSyncService _syncService;
  bool _isSignalRConnected = true;

  MessagesNotifier(
    this._messageRepository,
    this._outboxRepository,
    this.chatId,
    this._signalRService,
    this._cache,
    this._ref,
  ) : super(MessagesState()) {
    _syncService = MessageSyncService(_messageRepository);
    loadMessages();
    _monitorSignalRConnection();
  }

  /// Monitor SignalR connection state and perform incremental sync on reconnect
  void _monitorSignalRConnection() {
    // Check connection state periodically
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      final isConnected = _signalRService.isConnected;
      
      if (isConnected != _isSignalRConnected) {
        _isSignalRConnected = isConnected;
        
        if (!isConnected) {
          print('[SYNC] SignalR disconnected, starting status polling for chat: $chatId');
          _syncService.startPolling(
            chatId: chatId,
            onStatusUpdate: (messageId, status) {
              updateMessageStatus(messageId, status);
            },
          );
        } else {
          print('[SYNC] SignalR reconnected, performing incremental sync for chat: $chatId');
          _syncService.stopPolling();
          
          // Perform incremental sync to catch missed messages
          _performIncrementalSync();
        }
      }
      
      // Continue monitoring
      _monitorSignalRConnection();
    });
  }

  /// Perform incremental sync after SignalR reconnection
  Future<void> _performIncrementalSync() async {
    try {
      final localDataSource = _ref.read(localDataSourceProvider);
      
      // Get last sync timestamp from cache
      final lastSync = await localDataSource.getLastSyncTimestamp(chatId);
      final sinceTimestamp = lastSync ?? DateTime.now().subtract(const Duration(hours: 1));
      
      print('[SYNC] Incremental sync since: $sinceTimestamp');
      
      // Fetch updates from backend
      final updates = await _messageRepository.getMessageUpdates(
        chatId: chatId,
        since: sinceTimestamp,
        take: 100,
      );
      
      if (updates.isEmpty) {
        print('[SYNC] No new messages since last sync');
        return;
      }
      
      print('[SYNC] Received ${updates.length} message updates');
      
      // Merge updates with current state
      final currentMessages = state.messages;
      final messageMap = <String, Message>{
        for (var msg in currentMessages) msg.id: msg
      };
      
      // Add or update messages
      var hasChanges = false;
      for (var update in updates) {
        if (messageMap.containsKey(update.id)) {
          // Update existing message (e.g., status changed)
          final existing = messageMap[update.id]!;
          if (existing.status != update.status || 
              existing.content != update.content) {
            messageMap[update.id] = update;
            hasChanges = true;
          }
        } else {
          // New message
          messageMap[update.id] = update;
          hasChanges = true;
        }
        
        // Add to LRU cache
        _cache.put(update);
      }
      
      if (hasChanges) {
        // Update state with merged messages
        final List<Message> mergedMessages = messageMap.values.toList().cast<Message>();
        mergedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        state = state.copyWith(messages: mergedMessages);
        print('[SYNC] Incremental sync completed: merged ${updates.length} updates');
      }
      
      // Trigger final status sync
      _syncService.syncNow(
        chatId: chatId,
        onStatusUpdate: (messageId, status) {
          updateMessageStatus(messageId, status);
        },
      );
    } catch (e) {
      print('[SYNC] Incremental sync failed: $e');
      // Fall back to full reload on error
      loadMessages(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  bool _isLoadingOlder = false;

  Future<void> loadMessages({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // STEP 1: Try LRU cache first for instant loading
      final cachedMessages = _cache.getChatMessages(chatId);
      
      if (cachedMessages.isNotEmpty && !forceRefresh) {
        print('[MSG_LOAD] Found ${cachedMessages.length} messages in LRU cache');
        state = state.copyWith(
          messages: cachedMessages,
          isLoading: false, // Show cached data immediately
        );
        // Continue loading from repository in background to get updates
      }
      
      // STEP 2: Load synced messages from repository (Hive cache or API)
      final List<Message> syncedMessages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      
      // STEP 3: Load pending messages from outbox
      final pendingMessages = await _outboxRepository.getPendingMessagesForChat(chatId);
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      // Convert pending messages to Message objects
      final List<Message> localMessages = pendingMessages
          .map((pm) => pm.toMessage(
                currentUser?.id ?? '',
                currentUser?.displayName ?? 'Me',
              ))
          .cast<Message>()
          .toList();
      
      // STEP 4: Merge synced and local messages, removing duplicates
      // Use localId as key since it's always unique
      final Map<String, Message> allMessages = <String, Message>{};
      
      // Add synced messages first (use localId if available, fallback to id)
      for (final msg in syncedMessages) {
        final key = (msg.localId?.isNotEmpty ?? false) ? msg.localId! : msg.id;
        if (key.isNotEmpty) {
          allMessages[key] = msg;
        }
      }
      
      // Add local messages (they won't override synced ones with same localId)
      for (final msg in localMessages) {
        final key = (msg.localId?.isNotEmpty ?? false) ? msg.localId! : msg.id;
        if (key.isNotEmpty && !allMessages.containsKey(key)) {
          allMessages[key] = msg;
        }
      }
      
      // Convert to list and sort by date
      final List<Message> messages = List<Message>.from(allMessages.values);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      print('[MSG_LOAD] Loaded ${messages.length} messages (${syncedMessages.length} synced + ${localMessages.length} local)');
      
      // STEP 5: Update LRU cache with fresh data
      _cache.putAll(messages);
      print('[MSG_LOAD] Updated LRU cache with ${messages.length} messages');
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
      
      // STEP 6: Гарантируем сохранение в Hive кэш (на случай если репозиторий не сохранил)
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        await localDataSource.cacheMessages(chatId, syncedMessages);
      } catch (e) {
        print('[MSG_LOAD] Failed to cache messages in Hive: $e');
      }
    } catch (e) {
      print('[MSG_LOAD] Load messages error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    print('[MSG_SEND] Starting local-first send for text message');
    state = state.copyWith(isSending: true);
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      final localId = _uuid.v4();
      final now = DateTime.now();
      
      final localMessage = Message(
        id: localId, // Temporary local ID
        chatId: chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.text,
        content: content,
        status: MessageStatus.sending,
        createdAt: now,
        localId: localId,
        isLocalOnly: true,
      );
      
      // STEP 2: Add to UI immediately (optimistic update)
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      print('[MSG_SEND] Message added to UI with local ID: $localId');
      
      // Add to LRU cache
      _cache.put(localMessage);
      
      // STEP 3: Add to outbox queue for persistence
      await _outboxRepository.addToOutbox(
        chatId: chatId,
        type: MessageType.text,
        content: content,
      );
      
      // STEP 4: Send to backend asynchronously
      _syncMessageToBackend(localId, MessageType.text, content: content);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local message: $e');
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }
  
  /// Sync a local message to the backend with exponential backoff
  Future<void> _syncMessageToBackend(String localId, MessageType type, {String? content, String? audioPath, int attemptNumber = 0}) async {
    const maxAttempts = 5;
    final backoffDelays = [1, 2, 4, 8, 16, 30]; // seconds
    
    try {
      print('[MSG_SEND] Syncing message to backend: $localId (attempt ${attemptNumber + 1}/$maxAttempts)');
      await _outboxRepository.markAsSyncing(localId);
      
      // Send via API
      final Message serverMessage;
      if (type == MessageType.text) {
        serverMessage = await _messageRepository.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
        );
      } else {
        serverMessage = await _messageRepository.sendAudioMessage(
          chatId: chatId,
          audioPath: audioPath!,
        );
      }
      
      print('[MSG_SEND] Message synced successfully. Server ID: ${serverMessage.id}');
      
      // Mark as synced in outbox
      await _outboxRepository.markAsSynced(localId, serverMessage.id);
      
      // Update message in UI: replace local ID with server ID and update status
      final messageIndex = state.messages.indexWhere((m) => m.id == localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        updatedMessages[messageIndex] = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
        );
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Message updated in UI with server ID: ${serverMessage.id}');
      }
      
      // Clean up outbox after a delay (keep for retry capability)
      Future.delayed(const Duration(minutes: 1), () {
        _outboxRepository.removePendingMessage(localId);
      });
      
    } catch (e) {
      print('[MSG_SEND] Failed to sync message to backend (attempt ${attemptNumber + 1}): $e');
      
      // Check if we should retry
      if (attemptNumber < maxAttempts - 1) {
        // Calculate backoff delay
        final delaySeconds = attemptNumber < backoffDelays.length 
            ? backoffDelays[attemptNumber] 
            : backoffDelays.last;
        
        print('[MSG_SEND] Will retry in $delaySeconds seconds...');
        
        // Mark as failed temporarily but will retry
        await _outboxRepository.markAsFailed(localId, 'Retrying... (${attemptNumber + 1}/$maxAttempts)');
        
        // Schedule retry with exponential backoff
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            _syncMessageToBackend(localId, type, content: content, audioPath: audioPath, attemptNumber: attemptNumber + 1);
          }
        });
      } else {
        // Max attempts reached, mark as permanently failed
        print('[MSG_SEND] Max retry attempts reached for message: $localId');
        await _outboxRepository.markAsFailed(localId, 'Failed after $maxAttempts attempts: ${e.toString()}');
        
        // Update message status to failed in UI
        final messageIndex = state.messages.indexWhere((m) => m.id == localId);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            status: MessageStatus.failed,
          );
          state = state.copyWith(messages: updatedMessages);
          print('[MSG_SEND] Message marked as permanently failed in UI: $localId');
        }
      }
    }
  }

  Future<void> sendAudioMessage(String audioPath) async {
    print('[MSG_SEND] Starting local-first send for audio message');
    state = state.copyWith(isSending: true);
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      final localId = _uuid.v4();
      final now = DateTime.now();
      
      final localMessage = Message(
        id: localId, // Temporary local ID
        chatId: chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.audio,
        localAudioPath: audioPath,
        status: MessageStatus.sending,
        createdAt: now,
        localId: localId,
        isLocalOnly: true,
      );
      
      // STEP 2: Add to UI immediately (optimistic update)
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      print('[MSG_SEND] Audio message added to UI with local ID: $localId');
      
      // Add to LRU cache
      _cache.put(localMessage);
      
      // STEP 3: Add to outbox queue for persistence
      await _outboxRepository.addToOutbox(
        chatId: chatId,
        type: MessageType.audio,
        localAudioPath: audioPath,
      );
      
      // STEP 4: Send to backend asynchronously
      _syncMessageToBackend(localId, MessageType.audio, audioPath: audioPath);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local audio message: $e');
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void addMessage(Message message) {
    // Проверяем, что сообщение для этого чата
    if (message.chatId != chatId) {
      return;
    }
    
    print('[MSG_RECV] Received message via SignalR: ${message.id}');
    
    // Check if this is a replacement for a local message
    // (when our own message comes back from server via SignalR)
    final profileState = _ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isFromMe = currentUserId != null && message.senderId == currentUserId;
    
    // If message is from me, check if we have a local version to replace
    if (isFromMe) {
      // Look for a pending local message with same content/time
      final localIndex = state.messages.indexWhere((m) => 
        m.isLocalOnly && 
        m.chatId == message.chatId &&
        m.content == message.content &&
        m.type == message.type &&
        m.createdAt.difference(message.createdAt).abs().inSeconds < 5
      );
      
      if (localIndex != -1) {
        // Replace local message with server message
        final updatedMessages = [...state.messages];
        final localMessage = updatedMessages[localIndex];
        final serverMessage = message.copyWith(
          localId: localMessage.localId,
          isLocalOnly: false,
        );
        updatedMessages[localIndex] = serverMessage;
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_RECV] Replaced local message with server message: ${message.id}');
        
        // Update LRU cache
        _cache.update(serverMessage);
        
        // Clean up outbox if we have a local ID
        if (localMessage.localId != null) {
          _outboxRepository.markAsSynced(localMessage.localId!, message.id);
        }
        
        // Cache the server message in Hive
        try {
          final localDataSource = _ref.read(localDataSourceProvider);
          localDataSource.addMessageToCache(chatId, serverMessage);
        } catch (e) {
          print('[MSG_RECV] Failed to cache message in Hive: $e');
        }
        return;
      }
    }
    
    // Check if message already exists by ID or localId
    final exists = state.messages.any((m) => 
      (message.id.isNotEmpty && m.id == message.id) || 
      ((message.localId?.isNotEmpty ?? false) && m.localId == message.localId)
    );
    
    if (!exists) {
      // Add new message and sort by date
      final newMessages = [...state.messages, message];
      newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        messages: newMessages,
      );
      
      print('[MSG_RECV] Added new message to state: ${message.id} (localId: ${message.localId ?? 'none'})');
      
      // Add to LRU cache
      _cache.put(message);
      
      // Save message to Hive cache for persistence
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        localDataSource.addMessageToCache(chatId, message);
      } catch (e) {
        print('[MSG_RECV] Failed to cache message in Hive: $e');
      }
      
      // Background download for audio messages
      if (message.type == MessageType.audio && 
          message.filePath != null && 
          message.filePath!.isNotEmpty) {
        _downloadAudioInBackground(message);
      }
    } else {
      print('[MSG_RECV] Message already exists, ignoring: ${message.id} (localId: ${message.localId ?? 'none'})');
    }
  }

  Future<void> _downloadAudioInBackground(Message message) async {
    try {
      final audioStorageService = _ref.read(audioStorageServiceProvider);
      final localDataSource = _ref.read(localDataSourceProvider);
      
      // Check if already downloaded
      final hasLocal = await audioStorageService.hasLocalAudio(message.id);
      if (hasLocal) return;
      
      // Download audio
      final audioUrl = '${message.filePath}';
      final localPath = await audioStorageService.saveAudioLocally(
        message.id,
        audioUrl.startsWith('http') ? audioUrl : 'https://messenger.rare-books.ru${audioUrl}'
      );
      
      if (localPath != null) {
        // Update cache
        await localDataSource.updateMessageLocalAudioPath(
          message.chatId,
          message.id,
          localPath
        );
        
        // Update message in state
        final messageIndex = state.messages.indexWhere((m) => m.id == message.id);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            localAudioPath: localPath
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
    } catch (e) {
      // Silently fail - user can download on play
      print('[MessagesProvider] Background audio download failed: $e');
    }
  }

  void updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final updatedMessages = [...state.messages];
      final oldMessage = updatedMessages[messageIndex];
      final oldStatus = oldMessage.status;
      
      if (oldStatus != status) {
        final updatedMessage = oldMessage.copyWith(status: status);
        updatedMessages[messageIndex] = updatedMessage;
        
        state = state.copyWith(messages: updatedMessages);
        
        print('[MSG_STATUS] Message status updated in chatId=$chatId: messageId=$messageId, $oldStatus -> $status');
        
        // Update LRU cache
        _cache.update(updatedMessage);
        
        // Сохраняем обновленный статус в Hive кэш
        try {
          final localDataSource = _ref.read(localDataSourceProvider);
          localDataSource.updateMessageStatus(chatId, messageId, status);
          print('[MSG_STATUS] Message status cached in Hive: $messageId -> $status');
        } catch (e) {
          print('[MSG_STATUS] Failed to cache message status in Hive: $e');
        }
      } else {
        print('[MSG_STATUS] Message status unchanged for messageId=$messageId: $status');
      }
    } else {
      print('[MSG_STATUS] Message not found for status update: messageId=$messageId in chatId=$chatId');
    }
  }

  Future<void> markMessagesAsRead() async {
    try {
      // Get current user ID
      final profileState = _ref.read(profileProvider);
      final currentUserId = profileState.profile?.id;
      
      if (currentUserId == null) return;
      
      // Find all unread messages from other users
      final unreadMessages = state.messages.where((message) {
        return message.senderId != currentUserId && 
               message.status != MessageStatus.read;
      }).toList();
      
      if (unreadMessages.isEmpty) return;
      
      print('[STATUS_UPDATE] Marking ${unreadMessages.length} messages as read');
      
      // Batch mark via SignalR (for real-time)
      for (final message in unreadMessages) {
        try {
          await _signalRService.markMessageAsRead(message.id, chatId);
          
          // Update local status immediately
          updateMessageStatus(message.id, MessageStatus.read);
        } catch (e) {
          print('[STATUS_UPDATE] Failed to mark message ${message.id} as read via SignalR: $e');
        }
      }
      
      // Also send batch request via REST API as fallback
      try {
        final messageIds = unreadMessages.map((m) => m.id).toList();
        await _messageRepository.batchMarkAsRead(messageIds);
        print('[STATUS_UPDATE] Batch read confirmation sent via REST API');
      } catch (e) {
        print('[STATUS_UPDATE] Failed to send batch read via REST API: $e');
      }
    } catch (e) {
      print('[STATUS_UPDATE] Failed to mark messages as read: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _messageRepository.deleteMessage(messageId);
      // Message will be removed from state via SignalR notification
    } catch (e) {
      print('[MessagesProvider] Failed to delete message: $e');
      rethrow;
    }
  }

  void removeMessage(String messageId) {
    final updatedMessages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  /// Manually retry a failed message
  Future<void> retryFailedMessage(String localId) async {
    try {
      print('[MSG_RETRY] Manually retrying failed message: $localId');
      
      // Get pending message from outbox
      final pendingMessage = await _outboxRepository.getAllPendingMessages()
          .then((messages) => messages.firstWhere((m) => m.localId == localId));
      
      // Reset retry count and mark for sync
      await _outboxRepository.retryMessage(localId);
      
      // Update UI status to sending
      final messageIndex = state.messages.indexWhere((m) => 
          m.id == localId || m.localId == localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
          status: MessageStatus.sending,
        );
        state = state.copyWith(messages: updatedMessages);
      }
      
      // Trigger sync
      _syncMessageToBackend(
        localId, 
        pendingMessage.type,
        content: pendingMessage.content,
        audioPath: pendingMessage.localAudioPath,
        attemptNumber: 0, // Reset attempt counter
      );
    } catch (e) {
      print('[MSG_RETRY] Failed to retry message: $e');
    }
  }

  /// Load older messages using cursor pagination (for "Load More")
  Future<void> loadOlderMessages() async {
    // Prevent concurrent loads
    if (_isLoadingOlder || state.isLoading) {
      print('[MSG_LOAD] Already loading, skipping...');
      return;
    }

    _isLoadingOlder = true;
    
    try {
      // Get the oldest message as cursor
      if (state.messages.isEmpty) {
        print('[MSG_LOAD] No messages to use as cursor');
        _isLoadingOlder = false;
        return;
      }

      final oldestMessage = state.messages.first;
      final cursor = oldestMessage.id;
      
      print('[MSG_LOAD] Loading older messages with cursor: $cursor');
      
      // Fetch older messages
      final olderMessages = await _messageRepository.getOlderMessagesWithCursor(
        chatId: chatId,
        cursor: cursor,
        take: 30,
      );
      
      if (olderMessages.isEmpty) {
        print('[MSG_LOAD] No more older messages');
        _isLoadingOlder = false;
        return;
      }
      
      print('[MSG_LOAD] Loaded ${olderMessages.length} older messages');
      
      // Merge with current messages (avoid duplicates)
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages = olderMessages.where((m) => !existingIds.contains(m.id)).toList();
      
      if (newMessages.isEmpty) {
        print('[MSG_LOAD] All loaded messages were duplicates');
        _isLoadingOlder = false;
        return;
      }
      
      // Prepend older messages to current list
      final List<Message> allMessages = [...newMessages, ...state.messages];
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Update LRU cache
      _cache.putAll(newMessages);
      
      state = state.copyWith(messages: allMessages);
      
      print('[MSG_LOAD] Cursor pagination completed: added ${newMessages.length} messages');
    } catch (e) {
      print('[MSG_LOAD] Failed to load older messages: $e');
      state = state.copyWith(error: e.toString());
    } finally {
      _isLoadingOlder = false;
    }
  }

  /// Check if there are potentially more older messages to load
  bool get canLoadMore => state.messages.length >= 30; // Arbitrary threshold
}


