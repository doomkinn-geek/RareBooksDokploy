import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../data/services/message_sync_service.dart';
import '../../data/repositories/message_cache_repository.dart';
import '../../data/repositories/outbox_repository.dart';
import 'auth_provider.dart';
import 'signalr_provider.dart';
import 'profile_provider.dart';
import 'chats_provider.dart';
import 'dart:io';
import 'dart:convert';

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
      ref.read(statusUpdateQueueRepositoryProvider),
      ref.read(statusSyncServiceProvider),
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
  final dynamic _statusQueue;
  final dynamic _statusSyncService;
  final Ref _ref;
  final _uuid = const Uuid();
  late final MessageSyncService _syncService;
  bool _isSignalRConnected = true;
  
  // Throttling: track pending sends to prevent spam
  final Set<String> _pendingSends = {};
  DateTime? _lastSendTime;

  MessagesNotifier(
    this._messageRepository,
    this._outboxRepository,
    this.chatId,
    this._signalRService,
    this._cache,
    this._statusQueue,
    this._statusSyncService,
    this._ref,
  ) : super(MessagesState()) {
    _syncService = MessageSyncService(_messageRepository);
    loadMessages();
    _monitorSignalRConnection();
    _startPeriodicSync();
    
    // Start status sync service
    _statusSyncService.startPeriodicSync();
  }

  // #region agent log helper
  Future<void> _logToFile(String event, Map<String, dynamic> data) async {
    try {
      final logEntry = jsonEncode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'location': 'messages_provider.dart',
        'event': event,
        'data': data,
        'sessionId': 'debug-session',
      });
      final file = File('d:\\_SOURCES\\source\\RareBooksServicePublic\\.cursor\\debug.log');
      await file.writeAsString('$logEntry\n', mode: FileMode.append);
    } catch (e) {
      print('[LOG_ERROR] Failed to write log: $e');
    }
  }
  // #endregion

  /// Periodic message sync to catch any missed messages (runs every 30 seconds)
  void _startPeriodicSync() {
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      
      // Only sync if we're online (SignalR connected)
      if (_isSignalRConnected) {
        print('[SYNC] Running periodic message sync for chat: $chatId');
        _performIncrementalSync();
      }
      
      // Schedule next sync
      _startPeriodicSync();
    });
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
          
          // Force sync of pending status updates
          _statusSyncService.forceSync().catchError((e) {
            print('[SYNC] Failed to force sync status updates: $e');
          });
        }
      }
      
      // Continue monitoring
      _monitorSignalRConnection();
    });
  }

  /// Perform incremental sync after SignalR reconnection or periodically
  Future<void> _performIncrementalSync() async {
    try {
      final localDataSource = _ref.read(localDataSourceProvider);
      
      // Get last sync timestamp from cache
      final lastSync = await localDataSource.getLastSyncTimestamp(chatId);
      final sinceTimestamp = lastSync ?? DateTime.now().subtract(const Duration(hours: 1));
      
      print('[SYNC] Incremental sync for chat $chatId since: $sinceTimestamp');
      
      // Fetch updates from backend
      final updates = await _messageRepository.getMessageUpdates(
        chatId: chatId,
        since: sinceTimestamp,
        take: 100,
      );
      
      if (updates.isEmpty) {
        print('[SYNC] No new messages since last sync');
        // Update sync timestamp even if no changes
        await localDataSource.saveLastSyncTimestamp(chatId, DateTime.now());
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
            print('[SYNC] Updated message ${update.id}: status=${update.status}');
          }
        } else {
          // New message
          messageMap[update.id] = update;
          hasChanges = true;
          print('[SYNC] New message ${update.id} from incremental sync');
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
        
        // Update chat list to reflect new messages
        _ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      }
      
      // Update last sync timestamp
      await localDataSource.saveLastSyncTimestamp(chatId, DateTime.now());
      
      // Trigger final status sync
      _syncService.syncNow(
        chatId: chatId,
        onStatusUpdate: (messageId, status) {
          updateMessageStatus(messageId, status);
        },
      );
    } catch (e) {
      print('[SYNC] Incremental sync failed: $e');
      // Don't fall back to full reload unless absolutely necessary
      // Just log the error and try again on next periodic sync
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
      print('[MSG_LOAD] ========== STARTING LOAD MESSAGES ========== forceRefresh=$forceRefresh');
      
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
      print('[MSG_LOAD] Loading synced messages from repository...');
      final List<Message> syncedMessages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      print('[MSG_LOAD] Loaded ${syncedMessages.length} synced messages from repository');
      for (final msg in syncedMessages.take(5)) {
        print('[MSG_LOAD]   - Synced: id=${msg.id}, localId=${msg.localId}, content="${msg.content}", isLocalOnly=${msg.isLocalOnly}');
      }
      
      // STEP 3: Load pending messages from outbox
      // All messages in outbox should be truly pending (not synced),
      // since we now immediately delete synced messages
      print('[MSG_LOAD] Loading pending messages from outbox...');
      final pendingMessages = await _outboxRepository.getPendingMessagesForChat(chatId);
      
      print('[MSG_LOAD] Found ${pendingMessages.length} pending messages in outbox');
      for (final pm in pendingMessages) {
        print('[MSG_LOAD]   - Outbox: localId=${pm.localId}, serverId=${pm.serverId}, state=${pm.syncState}, content="${pm.content}"');
      }
      
      // NOTE: Defensive cleanup removed - OutboxRepository now handles cleanup immediately on sync
      // Synced messages are removed instantly, so they should never appear here
      print('[MSG_LOAD] Outbox contains ${pendingMessages.length} pending messages (no cleanup needed)');
      
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      print('[MSG_LOAD] Current user: ${currentUser?.id} (${currentUser?.displayName})');
      
      // Convert pending messages to Message objects
      final List<Message> localMessages = pendingMessages
          .map((pm) => pm.toMessage(
                currentUser?.id ?? '',
                currentUser?.displayName ?? 'Me',
              ))
          .cast<Message>()
          .toList();
      
      print('[MSG_LOAD] Converted ${localMessages.length} pending messages to Message objects');
      for (final msg in localMessages) {
        print('[MSG_LOAD]   - Local: id=${msg.id}, senderId=${msg.senderId}, content="${msg.content}", isLocalOnly=${msg.isLocalOnly}');
      }
      
      // STEP 4: Merge synced and local messages, removing duplicates
      // Simplified: Use clientMessageId for matching (most reliable)
      final Map<String, Message> allMessages = <String, Message>{};
      
      print('[MSG_LOAD] Merging messages...');
      
      // Add synced messages first (use clientMessageId if available, fallback to id)
      for (final msg in syncedMessages) {
        final key = (msg.clientMessageId?.isNotEmpty ?? false) ? msg.clientMessageId! : msg.id;
        if (key.isNotEmpty) {
          allMessages[key] = msg;
          print('[MSG_LOAD]   + Added synced message with key=$key, id=${msg.id}');
        }
      }
      
      print('[MSG_LOAD] After adding synced: ${allMessages.length} unique messages');
      
      // Add local messages (use localId as key for pending messages)
      // They won't override synced ones if clientMessageId matches
      int skipped = 0;
      for (final msg in localMessages) {
        // For local messages, use localId as key (they don't have server ID yet)
        final key = msg.id; // This is actually localId for pending messages
        if (key.isNotEmpty && !allMessages.containsKey(key)) {
          allMessages[key] = msg;
          print('[MSG_LOAD]   + Added local message with key=$key');
        } else {
          skipped++;
          print('[MSG_LOAD]   - Skipped duplicate local message with key=$key');
        }
      }
      
      print('[MSG_LOAD] After adding local: ${allMessages.length} unique messages, skipped=$skipped duplicates');
      
      // Convert to list and sort by date
      final List<Message> messages = List<Message>.from(allMessages.values);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      print('[MSG_LOAD] Final result: ${messages.length} messages total');
      print('[MSG_LOAD] ========== LOAD MESSAGES COMPLETE ==========');
      
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
    
    // Throttling: prevent too frequent sends (max 10 per second per user)
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 100) {
      print('[MSG_SEND] Throttling: too frequent sends, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastSendTime = now;
    
    state = state.copyWith(isSending: true);
    
    // Declare localId outside try block so it's accessible in catch
    String? localId;
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      localId = _uuid.v4();
      
      // Check if this message is already being sent (double-tap prevention)
      if (_pendingSends.contains(localId)) {
        print('[MSG_SEND] Message already being sent, skipping: $localId');
        state = state.copyWith(isSending: false);
        return;
      }
      
      _pendingSends.add(localId);
      
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
      
      // Update chat preview immediately for better UX
      try {
        _ref.read(chatsProvider.notifier).updateChatLastMessage(
          chatId, 
          localMessage, 
          incrementUnread: false,
        );
      } catch (e) {
        print('[MSG_SEND] Failed to update chat preview: $e');
      }
      
      // STEP 3: Add to outbox queue for persistence
      final outboxEntry = await _outboxRepository.addToOutbox(
        chatId: chatId,
        type: MessageType.text,
        content: content,
      );
      final outboxId = outboxEntry.localId; // Save outbox ID for later cleanup
      
      // STEP 4: Send to backend asynchronously with clientMessageId
      _syncMessageToBackend(localId, MessageType.text, outboxId: outboxId, content: content, clientMessageId: localId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local message: $e');
      if (localId != null) {
        _pendingSends.remove(localId);
      }
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }
  
  /// Sync a local message to the backend with exponential backoff
  Future<void> _syncMessageToBackend(String localId, MessageType type, {String? outboxId, String? content, String? audioPath, String? clientMessageId, int attemptNumber = 0}) async {
    const maxAttempts = 5;
    final backoffDelays = [1, 2, 4, 8, 16, 30]; // seconds
    
    try {
      print('[MSG_SEND] Syncing message to backend: localId=$localId, outboxId=$outboxId (attempt ${attemptNumber + 1}/$maxAttempts)');
      if (outboxId != null) {
        await _outboxRepository.markAsSyncing(outboxId);
      }
      
      // Send via API with clientMessageId for idempotency
      final Message serverMessage;
      if (type == MessageType.text) {
        serverMessage = await _messageRepository.sendMessage(
          chatId: chatId,
          type: type,
          content: content,
          clientMessageId: clientMessageId,
        );
      } else {
        // #region agent log - Hypothesis B: Check clientMessageId for audio
        await _logToFile('AUDIO_SEND', {'localId': localId, 'clientMessageId': clientMessageId, 'type': type.toString()});
        // #endregion
        serverMessage = await _messageRepository.sendAudioMessage(
          chatId: chatId,
          audioPath: audioPath!,
          clientMessageId: clientMessageId,
        );
      }
      
      print('[MSG_SEND] Message synced successfully. Server ID: ${serverMessage.id}');
      
      // Remove from pending sends
      _pendingSends.remove(localId);
      
      // IMMEDIATELY remove from outbox after successful sync using correct outboxId
      // Don't wait - this prevents duplicates on app restart
      if (outboxId != null) {
        await _outboxRepository.removePendingMessage(outboxId);
        print('[MSG_SEND] ✅ Removed message from outbox using outboxId: $outboxId');
      } else {
        // Fallback: try to remove by message localId (for backwards compatibility)
        await _outboxRepository.removePendingMessage(localId);
        print('[MSG_SEND] ⚠️ Removed message from outbox using localId (no outboxId): $localId');
      }
      
      // Update message in UI: replace local ID with server ID and update status
      final messageIndex = state.messages.indexWhere((m) => m.id == localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        final finalServerMessage = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
        );
        updatedMessages[messageIndex] = finalServerMessage;
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Message updated in UI with server ID: ${serverMessage.id}');
        
        // Update chat preview with server message (has correct server ID now)
        try {
          _ref.read(chatsProvider.notifier).updateChatLastMessage(
            chatId, 
            finalServerMessage, 
            incrementUnread: false,
          );
        } catch (e) {
          print('[MSG_SEND] Failed to update chat preview with server message: $e');
        }
      }
      
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
            _syncMessageToBackend(localId, type, content: content, audioPath: audioPath, clientMessageId: clientMessageId, attemptNumber: attemptNumber + 1);
          }
        });
      } else {
        // Max attempts reached, mark as permanently failed
        print('[MSG_SEND] Max retry attempts reached for message: $localId');
        _pendingSends.remove(localId);
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

  Future<void> _syncImageToBackend(String localId, String imagePath, {String? clientMessageId, int attemptNumber = 0}) async {
    const maxAttempts = 5;
    final backoffDelays = [1, 2, 4, 8, 16, 30]; // seconds
    
    try {
      print('[MSG_SEND] Syncing image to backend: $localId (attempt ${attemptNumber + 1}/$maxAttempts)');
      // #region agent log - Hypothesis B: Check clientMessageId for image
      await _logToFile('IMAGE_SEND', {'localId': localId, 'clientMessageId': clientMessageId, 'imagePath': imagePath});
      // #endregion
      
      // Send via API with clientMessageId
      final serverMessage = await _messageRepository.sendImageMessage(
        chatId: chatId,
        imagePath: imagePath,
        clientMessageId: clientMessageId,
      );
      
      print('[MSG_SEND] Image synced successfully. Server ID: ${serverMessage.id}');
      
      // Remove from pending sends
      _pendingSends.remove(localId);
      
      // IMMEDIATELY remove from outbox after successful sync
      await _outboxRepository.removePendingMessage(localId);
      print('[MSG_SEND] Removed image message from outbox: $localId');
      
      // Update message in UI: replace local ID with server ID and update status
      final messageIndex = state.messages.indexWhere((m) => m.id == localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        final finalServerMessage = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
        );
        updatedMessages[messageIndex] = finalServerMessage;
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Image message updated in UI with server ID: ${serverMessage.id}');
        
        // Update chat preview with server message
        try {
          _ref.read(chatsProvider.notifier).updateChatLastMessage(
            chatId, 
            finalServerMessage, 
            incrementUnread: false,
          );
        } catch (e) {
          print('[MSG_SEND] Failed to update chat preview with server message: $e');
        }
      }
      
    } catch (e) {
      print('[MSG_SEND] Failed to sync image to backend (attempt ${attemptNumber + 1}): $e');
      
      // Check if we should retry
      if (attemptNumber < maxAttempts - 1) {
        final delaySeconds = attemptNumber < backoffDelays.length 
            ? backoffDelays[attemptNumber] 
            : backoffDelays.last;
        
        print('[MSG_SEND] Will retry in $delaySeconds seconds...');
        
        // Schedule retry with exponential backoff
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            _syncImageToBackend(localId, imagePath, clientMessageId: clientMessageId, attemptNumber: attemptNumber + 1);
          }
        });
      } else {
        // Max attempts reached, mark as permanently failed
        print('[MSG_SEND] Max retry attempts reached for image: $localId');
        _pendingSends.remove(localId);
        
        // Update message status to failed in UI
        final messageIndex = state.messages.indexWhere((m) => m.id == localId);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            status: MessageStatus.failed,
          );
          state = state.copyWith(messages: updatedMessages);
          print('[MSG_SEND] Image message marked as permanently failed in UI: $localId');
        }
      }
    }
  }

  Future<void> sendAudioMessage(String audioPath) async {
    print('[MSG_SEND] Starting local-first send for audio message');
    
    // Throttling: prevent too frequent sends
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 100) {
      print('[MSG_SEND] Throttling: too frequent sends, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastSendTime = now;
    
    state = state.copyWith(isSending: true);
    
    // Declare localId outside try block so it's accessible in catch
    String? localId;
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID and clientMessageId
      localId = _uuid.v4();
      final clientMessageId = localId; // Use same UUID for both
      
      // Check if this message is already being sent
      if (_pendingSends.contains(localId)) {
        print('[MSG_SEND] Message already being sent, skipping: $localId');
        state = state.copyWith(isSending: false);
        return;
      }
      
      _pendingSends.add(localId);
      
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
        clientMessageId: clientMessageId, // Add clientMessageId for deduplication
      );
      
      // STEP 2: Add to UI immediately (optimistic update)
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      print('[MSG_SEND] Audio message added to UI with local ID: $localId, clientMessageId: $clientMessageId');
      
      // Add to LRU cache
      _cache.put(localMessage);
      
      // Update chat preview immediately for better UX
      try {
        _ref.read(chatsProvider.notifier).updateChatLastMessage(
          chatId, 
          localMessage, 
          incrementUnread: false,
        );
      } catch (e) {
        print('[MSG_SEND] Failed to update chat preview: $e');
      }
      
      // STEP 3: Add to outbox queue for persistence
      final outboxEntry = await _outboxRepository.addToOutbox(
        chatId: chatId,
        type: MessageType.audio,
        localAudioPath: audioPath,
      );
      final outboxId = outboxEntry.localId; // Save outbox ID for later cleanup
      
      // STEP 4: Send to backend asynchronously with clientMessageId
      _syncMessageToBackend(localId, MessageType.audio, outboxId: outboxId, audioPath: audioPath, clientMessageId: clientMessageId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local audio message: $e');
      if (localId != null) {
        _pendingSends.remove(localId);
      }
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendImageMessage(String imagePath) async {
    print('[MSG_SEND] Starting local-first send for image message');
    
    // Throttling: prevent too frequent sends
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 100) {
      print('[MSG_SEND] Throttling: too frequent sends, waiting...');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastSendTime = now;
    
    state = state.copyWith(isSending: true);
    
    // Declare localId outside try block so it's accessible in catch
    String? localId;
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID and clientMessageId
      localId = _uuid.v4();
      final clientMessageId = localId; // Use same UUID for both
      
      // Check if this message is already being sent
      if (_pendingSends.contains(localId)) {
        print('[MSG_SEND] Message already being sent, skipping: $localId');
        state = state.copyWith(isSending: false);
        return;
      }
      
      _pendingSends.add(localId);
      
      final localMessage = Message(
        id: localId, // Temporary local ID
        chatId: chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.image,
        localImagePath: imagePath,
        status: MessageStatus.sending,
        createdAt: now,
        localId: localId,
        isLocalOnly: true,
        clientMessageId: clientMessageId, // Add clientMessageId for deduplication
      );
      
      // STEP 2: Add to UI immediately (optimistic update)
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      print('[MSG_SEND] Image message added to UI with local ID: $localId, clientMessageId: $clientMessageId');
      
      // Add to LRU cache
      _cache.put(localMessage);
      
      // Update chat preview immediately for better UX
      try {
        _ref.read(chatsProvider.notifier).updateChatLastMessage(
          chatId, 
          localMessage, 
          incrementUnread: false,
        );
      } catch (e) {
        print('[MSG_SEND] Failed to update chat preview: $e');
      }
      
      // STEP 3: Send to backend asynchronously with clientMessageId
      _syncImageToBackend(localId, imagePath, clientMessageId: clientMessageId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local image message: $e');
      if (localId != null) {
        _pendingSends.remove(localId);
      }
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
    
    print('[MSG_RECV] Received message via SignalR: ${message.id} (clientMessageId: ${message.clientMessageId ?? 'none'})');
    // #region agent log - Hypothesis A/D: Track incoming message
    _logToFile('MSG_RECEIVED', {
      'messageId': message.id,
      'clientMessageId': message.clientMessageId,
      'localId': message.localId,
      'type': message.type.toString(),
      'isLocalOnly': message.isLocalOnly,
      'currentMessages': state.messages.length,
    });
    // #endregion
    
    // Check if this is a replacement for a local message
    // (when our own message comes back from server via SignalR)
    final profileState = _ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isFromMe = currentUserId != null && message.senderId == currentUserId;
    
    // If message is from me, check if we have a local version to replace
    if (isFromMe) {
      int localIndex = -1;
      
      // 1. BEST: Точное сопоставление по clientMessageId (самый надежный способ)
      if (message.clientMessageId != null && message.clientMessageId!.isNotEmpty) {
        localIndex = state.messages.indexWhere((m) => 
          m.localId == message.clientMessageId || 
          m.clientMessageId == message.clientMessageId
        );
        
        if (localIndex != -1) {
          print('[MSG_RECV] Found local message by clientMessageId: ${message.clientMessageId}');
        }
      }
      
      // 2. FALLBACK: Сопоставление по содержимому (для обратной совместимости)
      if (localIndex == -1) {
        localIndex = state.messages.indexWhere((m) => 
          m.isLocalOnly && 
          m.chatId == message.chatId &&
          m.type == message.type &&
          _matchContent(m, message) &&
          m.createdAt.difference(message.createdAt).abs().inSeconds < 5
        );
        
        if (localIndex != -1) {
          print('[MSG_RECV] Found local message by content matching');
        }
      }
      
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
      } else {
      }
    }
    
    // Simplified deduplication: check only by server ID and clientMessageId
    // Server-side idempotency handles duplicates, so complex matching is unnecessary
    final exists = state.messages.any((m) {
      // Check by server ID (most reliable)
      if (message.id.isNotEmpty && m.id == message.id) {
        print('[MSG_RECV] Duplicate detected by server ID: ${message.id}');
        return true;
      }
      
      // Check by clientMessageId (for messages that came back from server)
      if ((message.clientMessageId?.isNotEmpty ?? false) && 
          m.clientMessageId == message.clientMessageId) {
        print('[MSG_RECV] Duplicate detected by clientMessageId: ${message.clientMessageId}');
        return true;
      }
      
      return false;
    });
    
    if (!exists) {
      // Add new message and sort by date
      final newMessages = [...state.messages, message];
      newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        messages: newMessages,
      );
      
      print('[MSG_RECV] Added new message to state: ${message.id} (localId: ${message.localId ?? 'none'}, clientMessageId: ${message.clientMessageId ?? 'none'})');
      
      // Add to LRU cache
      _cache.put(message);
      
      // Update chat preview with this message
      try {
        _ref.read(chatsProvider.notifier).updateChatLastMessage(
          chatId, 
          message, 
          incrementUnread: false, // Don't increment as it's already handled by SignalR
        );
      } catch (e) {
        print('[MSG_RECV] Failed to update chat preview: $e');
      }
      
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
      print('[MSG_RECV] Message already exists, ignoring: ${message.id} (localId: ${message.localId ?? 'none'}, clientMessageId: ${message.clientMessageId ?? 'none'})');
    }
  }
  
  /// Helper method to match content between local and server messages
  /// Simplified: Only match by clientMessageId (server handles idempotency)
  bool _matchContent(Message local, Message server) {
    // Primary matching by clientMessageId
    if (local.clientMessageId != null && 
        local.clientMessageId == server.clientMessageId) {
      return true;
    }
    
    // Fallback: check if localId matches clientMessageId
    if (local.localId != null && 
        local.localId == server.clientMessageId) {
      return true;
    }
    
    return false;
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
        // Debug: track where status update comes from
        print('[MSG_STATUS] Stack trace for status update:');
        print(StackTrace.current.toString().split('\n').take(5).join('\n'));
        
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
      print('[STATUS_UPDATE] markMessagesAsRead called');
      // Get current user ID
      final profileState = _ref.read(profileProvider);
      final currentUserId = profileState.profile?.id;
      
      if (currentUserId == null) {
        print('[STATUS_UPDATE] currentUserId is null, returning');
        return;
      }
      
      print('[STATUS_UPDATE] currentUserId: $currentUserId, total messages: ${state.messages.length}');
      
      // Find all unread messages from other users
      final unreadMessages = state.messages.where((message) {
        return message.senderId != currentUserId && 
               message.status != MessageStatus.read;
      }).toList();
      
      print('[STATUS_UPDATE] Found ${unreadMessages.length} unread messages');
      
      if (unreadMessages.isEmpty) {
        print('[STATUS_UPDATE] No unread messages, returning');
        return;
      }
      
      print('[STATUS_UPDATE] Marking ${unreadMessages.length} messages as read');
      
      // Add to status queue for reliable delivery
      for (final message in unreadMessages) {
        await _statusQueue.enqueueStatusUpdate(message.id, MessageStatus.read);
      }
      
      // Update local status immediately for responsive UI
      for (final message in unreadMessages) {
        updateMessageStatus(message.id, MessageStatus.read);
      }
      
      // Try sending via SignalR for real-time (but queue ensures it happens eventually)
      for (final message in unreadMessages) {
        try {
          await _signalRService.markMessageAsRead(message.id, chatId);
        } catch (e) {
          print('[STATUS_UPDATE] Failed to mark message ${message.id} as read via SignalR: $e');
          // Queue will retry
        }
      }
      
      // Also send batch request via REST API
      try {
        final messageIds = unreadMessages.map((m) => m.id).toList();
        await _messageRepository.batchMarkAsRead(messageIds);
        print('[STATUS_UPDATE] Batch read confirmation sent via REST API');
      } catch (e) {
        print('[STATUS_UPDATE] Failed to send batch read via REST API: $e');
        // Queue will retry
      }
    } catch (e) {
      print('[STATUS_UPDATE] Failed to mark messages as read: $e');
    }
  }

  Future<void> markAudioAsPlayed(String messageId) async {
    try {
      // Add to status queue for reliable delivery
      await _statusQueue.enqueueStatusUpdate(messageId, MessageStatus.played);
      
      // Update local state immediately for responsive UI
      final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
          status: MessageStatus.played,
        );
        state = state.copyWith(messages: updatedMessages);
        print('[STATUS_UPDATE] Marked audio message as played locally: $messageId');
      }
      
      // Try calling API immediately (queue will retry if it fails)
      try {
        await _messageRepository.markAudioAsPlayed(messageId);
        print('[STATUS_UPDATE] Marked audio message as played via API: $messageId');
      } catch (e) {
        print('[STATUS_UPDATE] Failed to mark audio as played via API: $e');
        // Queue will retry
      }
    } catch (e) {
      print('[STATUS_UPDATE] Failed to mark audio as played: $e');
      // Don't rethrow - queue will handle it
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
        clientMessageId: localId, // Use localId as clientMessageId
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


