import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../data/models/chat_model.dart';
import '../../data/services/message_sync_service.dart';
import '../../data/repositories/message_cache_repository.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/encryption_service.dart';
import 'auth_provider.dart';
import 'signalr_provider.dart';
import 'profile_provider.dart';
import 'chats_provider.dart';
import 'chat_preview_sync_service.dart';

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
  final bool isLoadingOlder; // Loading older messages (pagination)
  final bool hasMoreOlder; // Are there more older messages to load?
  final bool isSending;
  final String? error;

  MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMoreOlder = true,
    this.isSending = false,
    this.error,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    bool? isSending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
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
  
  // Encryption: cached public key for this chat's other participant
  String? _otherParticipantPublicKey;

  // Track recently sent messages for status polling (messageId -> sentAt)
  final Map<String, DateTime> _recentlySentMessages = {};
  // Increased from 5s to 10s - SignalR is primary, polling is fallback only
  static const Duration _outgoingStatusPollInterval = Duration(seconds: 10);
  static const Duration _maxTrackingDuration = Duration(minutes: 2);
  
  // Centralized mapping localId -> serverId for reliable message lookup
  final Map<String, String> _localToServerIdMap = {};
  
  /// Register a mapping from localId to serverId
  void _registerIdMapping(String localId, String serverId) {
    if (localId != serverId) {
      _localToServerIdMap[localId] = serverId;
      print('[ID_MAP] Registered mapping: $localId -> $serverId');
    }
  }
  
  /// Find message index by ID, checking both id, localId, and the mapping
  int _findMessageIndex(String messageId) {
    // First try direct match by id
    var index = state.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) return index;
    
    // Try by localId
    index = state.messages.indexWhere((m) => m.localId == messageId);
    if (index != -1) return index;
    
    // Try resolving through mapping
    final resolvedId = _localToServerIdMap[messageId];
    if (resolvedId != null) {
      index = state.messages.indexWhere((m) => m.id == resolvedId);
      if (index != -1) return index;
    }
    
    // Try reverse lookup - check if messageId is a serverId and find by localId
    for (final entry in _localToServerIdMap.entries) {
      if (entry.value == messageId) {
        index = state.messages.indexWhere((m) => m.id == messageId || m.localId == entry.key);
        if (index != -1) return index;
      }
    }
    
    return -1;
  }

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
    loadMessages().then((_) => _applyCachedStatusUpdates());
    _monitorSignalRConnection();
    _startPeriodicSync();
    _startOutgoingStatusPolling();
    
    // Start status sync service
    _statusSyncService.startPeriodicSync();
    
    // Initialize encryption key from chat data
    _initializeEncryption();
  }
  
  /// Initialize encryption for this chat by caching the other participant's public key
  void _initializeEncryption() {
    try {
      final chatsState = _ref.read(chatsProvider);
      final chat = chatsState.chats.firstWhere(
        (c) => c.id == chatId,
        orElse: () => Chat(
          id: '', 
          type: ChatType.private, 
          title: '', 
          unreadCount: 0, 
          createdAt: DateTime.now(),
        ),
      );
      
      if (chat.id.isNotEmpty) {
        _otherParticipantPublicKey = chat.otherParticipantPublicKey;
        print('[ENCRYPTION] Initialized encryption for chat $chatId, hasPublicKey: ${_otherParticipantPublicKey != null}');
      }
    } catch (e) {
      print('[ENCRYPTION] Failed to initialize encryption: $e');
    }
  }
  
  /// Encrypt content for sending (for text messages)
  Future<String?> _encryptContent(String content) async {
    if (_otherParticipantPublicKey == null || _otherParticipantPublicKey!.isEmpty) {
      print('[ENCRYPTION] No public key available for encryption');
      return null;
    }
    
    try {
      final encryptionService = _ref.read(encryptionServiceProvider);
      final encrypted = await encryptionService.encryptForChat(
        chatId, 
        content, 
        _otherParticipantPublicKey,
      );
      print('[ENCRYPTION] Message encrypted successfully');
      return encrypted;
    } catch (e) {
      print('[ENCRYPTION] Encryption failed: $e');
      return null;
    }
  }
  
  /// Decrypt content from received message
  Future<String?> _decryptContent(String encryptedContent) async {
    if (_otherParticipantPublicKey == null || _otherParticipantPublicKey!.isEmpty) {
      // Try to refresh public key from chat
      _initializeEncryption();
      
      if (_otherParticipantPublicKey == null || _otherParticipantPublicKey!.isEmpty) {
        print('[ENCRYPTION] No public key available for decryption');
        return null;
      }
    }
    
    try {
      final encryptionService = _ref.read(encryptionServiceProvider);
      final decrypted = await encryptionService.decryptFromChat(
        chatId, 
        encryptedContent, 
        _otherParticipantPublicKey,
      );
      print('[ENCRYPTION] Message decrypted successfully');
      return decrypted;
    } catch (e) {
      print('[ENCRYPTION] Decryption failed: $e');
      return null;
    }
  }
  
  /// Decrypt a message if it's encrypted
  Future<Message> _decryptMessageIfNeeded(Message message) async {
    if (!message.isEncrypted || message.type != MessageType.text) {
      return message;
    }
    
    if (message.content == null || message.content!.isEmpty) {
      return message;
    }
    
    final decryptedContent = await _decryptContent(message.content!);
    if (decryptedContent != null) {
      return message.copyWith(content: decryptedContent);
    }
    
    // If decryption failed, mark the message as unreadable
    return message.copyWith(content: '[Не удалось расшифровать сообщение]');
  }
  
  /// Handle encrypted message - decrypt and add to state
  Future<void> _addEncryptedMessage(Message encryptedMessage) async {
    print('[ENCRYPTION] Decrypting incoming message: ${encryptedMessage.id}');
    
    // Decrypt the message
    final decryptedMessage = await _decryptMessageIfNeeded(encryptedMessage);
    
    // Add the decrypted message using the synchronous flow
    // We call the internal logic directly since addMessage would detect encryption again
    _addMessageInternal(decryptedMessage);
  }
  
  /// Internal method to add a message without encryption check (to avoid recursion)
  void _addMessageInternal(Message message) {
    // Check if this is a replacement for a local message
    // (when our own message comes back from server via SignalR)
    final profileState = _ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isFromMe = currentUserId != null && message.senderId == currentUserId;
    
    // If message is from me, check if we have a local version to replace
    if (isFromMe && message.clientMessageId != null && message.clientMessageId!.isNotEmpty) {
      final localIndex = state.messages.indexWhere((m) => 
        m.localId == message.clientMessageId || 
        m.clientMessageId == message.clientMessageId ||
        m.id == message.clientMessageId
      );
      
      if (localIndex != -1) {
        print('[MSG_RECV] Found local message by clientMessageId: ${message.clientMessageId}');
        
        final updatedMessages = [...state.messages];
        final localMessage = updatedMessages[localIndex];
        final serverMessage = message.copyWith(
          localId: localMessage.localId,
          isLocalOnly: false,
        );
        updatedMessages[localIndex] = serverMessage;
        state = state.copyWith(messages: updatedMessages);
        
        if (localMessage.localId != null) {
          _registerIdMapping(localMessage.localId!, message.id);
        }
        if (message.clientMessageId != null) {
          _registerIdMapping(message.clientMessageId!, message.id);
        }
        
        _cache.update(serverMessage);
        
        if (localMessage.localId != null) {
          _outboxRepository.markAsSynced(localMessage.localId!, message.id);
        }
        
        try {
          final localDataSource = _ref.read(localDataSourceProvider);
          localDataSource.addMessageToCache(chatId, serverMessage);
        } catch (e) {
          print('[MSG_RECV] Failed to cache message in Hive: $e');
        }
        return;
      }
    }
    
    // Check for duplicates
    final exists = state.messages.any((m) {
      if (message.id.isNotEmpty && m.id == message.id) {
        return true;
      }
      if ((message.clientMessageId?.isNotEmpty ?? false) && 
          (m.clientMessageId == message.clientMessageId || m.localId == message.clientMessageId)) {
        return true;
      }
      return false;
    });
    
    if (exists) {
      print('[MSG_RECV] Duplicate message, skipping: ${message.id}');
      return;
    }
    
    // Add the message
    final updatedMessages = [...state.messages, message];
    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: updatedMessages);
    
    _cache.put(message);
    
    try {
      final localDataSource = _ref.read(localDataSourceProvider);
      localDataSource.addMessageToCache(chatId, message);
    } catch (e) {
      print('[MSG_RECV] Failed to cache message in Hive: $e');
    }
    
    print('[MSG_RECV] Message added: ${message.id}');
  }
  
  /// Apply any pending status updates from the global cache
  /// This ensures we don't miss updates that arrived while this provider was not active
  void _applyCachedStatusUpdates() {
    try {
      if (state.messages.isEmpty) return;
      
      // Get all message IDs in this chat
      final messageIds = state.messages.map((m) => m.id).toList();
      
      // Consume cached status updates for these messages
      final pendingUpdates = _ref.read(pendingStatusUpdatesProvider.notifier)
          .consumeStatusUpdatesForMessages(messageIds);
      
      if (pendingUpdates.isEmpty) return;
      
      print('[STATUS_CACHE] Applying ${pendingUpdates.length} cached status updates for chat $chatId');
      
      // Apply each cached update
      for (final entry in pendingUpdates.entries) {
        updateMessageStatus(entry.key, entry.value);
      }
    } catch (e) {
      print('[STATUS_CACHE] Error applying cached status updates: $e');
    }
  }


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

  /// Polling fallback for outgoing message statuses
  /// Checks status of messages that are still in 'sending' or 'sent' state
  void _startOutgoingStatusPolling() {
    Future.delayed(_outgoingStatusPollInterval, () {
      if (!mounted) return;
      
      _checkOutgoingMessageStatuses();
      
      // Schedule next poll
      _startOutgoingStatusPolling();
    });
  }

  /// Check and update statuses for recently sent messages
  /// Uses batch API for efficiency instead of individual requests
  Future<void> _checkOutgoingMessageStatuses() async {
    try {
      // Get current user ID
      final profileState = _ref.read(profileProvider);
      final currentUserId = profileState.userId; // Uses cached userId for offline mode
      if (currentUserId == null) return;
      
      // Clean up old tracked messages
      final now = DateTime.now();
      _recentlySentMessages.removeWhere((id, sentAt) => 
        now.difference(sentAt) > _maxTrackingDuration
      );
      
      // Find messages that may need status updates from current user
      // Include 'sending', 'sent', AND 'delivered' to catch 'read' updates
      final pendingMessages = state.messages.where((m) => 
        m.senderId == currentUserId &&
        (m.status == MessageStatus.sending || 
         m.status == MessageStatus.sent ||
         m.status == MessageStatus.delivered) // Also check delivered for 'read' updates
      ).toList();
      
      if (pendingMessages.isEmpty) {
        return;
      }
      
      // Separate local-only messages (handle individually) from synced messages (batch query)
      final localOnlyMessages = pendingMessages.where((m) => m.isLocalOnly).toList();
      final syncedMessages = pendingMessages.where((m) => !m.isLocalOnly).toList();
      
      // Handle local-only messages individually
      for (final message in localOnlyMessages) {
        await _handleStuckLocalMessage(message, now);
      }
      
      // For synced messages, use batch status API
      if (syncedMessages.isEmpty) return;
      
      // Filter out messages we just sent (give SignalR a chance first)
      final messagesToCheck = syncedMessages.where((m) {
        final sentAt = _recentlySentMessages[m.id];
        return sentAt == null || now.difference(sentAt).inSeconds >= 3;
      }).toList();
      
      if (messagesToCheck.isEmpty) return;
      
      print('[OUTGOING_STATUS] Batch checking status for ${messagesToCheck.length} pending outgoing messages');
      
      try {
        // Use batch API for efficiency
        final messageIds = messagesToCheck.map((m) => m.id).toList();
        final statuses = await _messageRepository.getMessageStatuses(messageIds);
        
        // Update statuses for messages that changed
        for (final message in messagesToCheck) {
          final serverStatus = statuses[message.id];
          if (serverStatus != null && serverStatus != message.status) {
            print('[OUTGOING_STATUS] Status updated via batch polling: ${message.id} ${message.status} -> $serverStatus');
            updateMessageStatus(message.id, serverStatus);
            
            // Remove from tracking only if status is fully final (read or played)
            // Keep 'delivered' in tracking so we continue polling for 'read'
            if (serverStatus == MessageStatus.read ||
                serverStatus == MessageStatus.played) {
              _recentlySentMessages.remove(message.id);
            }
          }
        }
      } catch (e) {
        print('[OUTGOING_STATUS] Batch status check failed: $e');
        // Non-fatal, will retry on next poll
      }
    } catch (e) {
      print('[OUTGOING_STATUS] Error in status polling: $e');
    }
  }

  /// Handle messages stuck in 'sending' status (local-only, not yet synced)
  Future<void> _handleStuckLocalMessage(Message message, DateTime now) async {
    // Check how long the message has been stuck
    final messageAge = now.difference(message.createdAt);
    
    // OPTIMIZED TIMEOUT thresholds for better UX
    // User should get feedback quickly, but not falsely mark as failed
    const warningTimeout = Duration(seconds: 10);  // Log warning early
    const retryTimeout = Duration(seconds: 20);    // Trigger retry if still stuck
    const failureTimeout = Duration(seconds: 30);  // Mark as failed after 30s
    
    if (messageAge < warningTimeout) {
      // Still within normal sync window
      return;
    }
    
    print('[OUTGOING_STATUS] Local message ${message.id} stuck in sending for ${messageAge.inSeconds}s');
    
    // Check if message is in outbox
    try {
      final pendingMessages = await _outboxRepository.getPendingMessagesForChat(chatId);
      final outboxMessage = pendingMessages.where((pm) => 
        pm.localId == message.id || pm.localId == message.localId
      ).firstOrNull;
      
      if (outboxMessage != null) {
        // Message is in outbox - check its state
        if (outboxMessage.syncState == 'failed') {
          // Already marked as failed, update UI
          updateMessageStatus(message.id, MessageStatus.failed, force: true);
          print('[OUTGOING_STATUS] Message ${message.id} marked as failed (outbox state: failed)');
        } else if (messageAge >= failureTimeout) {
          // Timeout exceeded - mark as failed
          await _outboxRepository.markAsFailed(
            message.id, 
            'Message stuck in sending state for ${messageAge.inSeconds}s'
          );
          updateMessageStatus(message.id, MessageStatus.failed, force: true);
          print('[OUTGOING_STATUS] Message ${message.id} marked as failed (timeout after ${messageAge.inSeconds}s)');
        } else if (messageAge >= retryTimeout) {
          // Trigger retry if not already pending
          if (!_pendingSends.contains(message.id) && 
              !_pendingSends.contains(message.localId ?? '')) {
            print('[OUTGOING_STATUS] Message ${message.id} triggering automatic retry after ${messageAge.inSeconds}s');
            
            // Attempt automatic retry
            try {
              await retryFailedMessage(message.localId ?? message.id);
            } catch (e) {
              print('[OUTGOING_STATUS] Automatic retry failed: $e');
            }
          }
        }
      } else {
        // Not in outbox - message might have been synced but UI not updated
        // Try to find it on server by clientMessageId
        if (message.clientMessageId != null) {
          try {
            // This will update the UI if found
            await _performIncrementalSync();
          } catch (e) {
            print('[OUTGOING_STATUS] Incremental sync failed for stuck message: $e');
          }
        }
        
        // If still in sending state after sync attempt and timeout exceeded, mark as failed
        if (messageAge >= failureTimeout) {
          final currentMessage = state.messages.where((m) => m.id == message.id).firstOrNull;
          if (currentMessage != null && currentMessage.status == MessageStatus.sending) {
            updateMessageStatus(message.id, MessageStatus.failed, force: true);
            print('[OUTGOING_STATUS] Message ${message.id} marked as failed (not found on server after ${messageAge.inSeconds}s)');
          }
        }
      }
    } catch (e) {
      print('[OUTGOING_STATUS] Error handling stuck local message ${message.id}: $e');
    }
  }

  /// Track a recently sent message for status polling
  void _trackSentMessage(String messageId) {
    _recentlySentMessages[messageId] = DateTime.now();
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
    // #region agent log - Hypothesis A/E: Track loadMessages calls and concurrency
    print('[MSG_LOAD] HYP_A_ENTRY: loadMessages called - chatId: $chatId, forceRefresh: $forceRefresh, currentIsLoading: ${state.isLoading}, currentMessagesCount: ${state.messages.length}, timestamp: ${DateTime.now().toIso8601String()}');
    // #endregion
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('[MSG_LOAD] ========== STARTING LOAD MESSAGES ========== forceRefresh=$forceRefresh');
      
      // STEP 1: Try LRU cache first for instant loading
      // #region agent log - Hypothesis A: Track LRU cache hit
      final lruCacheStart = DateTime.now();
      // #endregion
      final cachedMessages = _cache.getChatMessages(chatId);
      // #region agent log - Hypothesis A
      print('[MSG_LOAD] HYP_A_LRU: LRU cache check took ${DateTime.now().difference(lruCacheStart).inMilliseconds}ms, found ${cachedMessages.length} messages');
      // #endregion
      
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
      // #region agent log - Hypothesis E: Track Hive/API load timing
      final repoLoadStart = DateTime.now();
      // #endregion
      List<Message> syncedMessages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      // #region agent log - Hypothesis E
      print('[MSG_LOAD] HYP_E_REPO: Repository load took ${DateTime.now().difference(repoLoadStart).inMilliseconds}ms, loaded ${syncedMessages.length} messages');
      // #endregion
      print('[MSG_LOAD] Loaded ${syncedMessages.length} synced messages from repository');
      
      // MERGE with cached messages, preserving local 'played' status
      // First try LRU cache (in-memory)
      syncedMessages = _mergeMessagesPreservingPlayedStatus(cachedMessages, syncedMessages);
      
      // Also check Hive cache for played statuses (persisted across app restarts)
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        final hiveStatuses = await localDataSource.getCachedMessageStatuses(chatId);
        if (hiveStatuses.isNotEmpty) {
          syncedMessages = _mergeMessagesWithHiveStatuses(syncedMessages, hiveStatuses);
        }
      } catch (e) {
        print('[MSG_LOAD] Failed to merge with Hive statuses: $e');
      }
      print('[MSG_LOAD] Merged with cached messages to preserve played status');
      
      for (final msg in syncedMessages.take(5)) {
        print('[MSG_LOAD]   - Synced: id=${msg.id}, localId=${msg.localId}, content="${msg.content}", isLocalOnly=${msg.isLocalOnly}, status=${msg.status}');
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
      // #region agent log - Hypothesis A: Track final state update
      print('[MSG_LOAD] HYP_A_FINAL: Final messages count: ${messages.length}, updating state...');
      // #endregion
      print('[MSG_LOAD] ========== LOAD MESSAGES COMPLETE ==========');
      
      // STEP 5: Update LRU cache with fresh data
      _cache.putAll(messages);
      print('[MSG_LOAD] Updated LRU cache with ${messages.length} messages');
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
      // #region agent log - Hypothesis A
      print('[MSG_LOAD] HYP_A_STATE_UPDATED: State updated with ${messages.length} messages, isLoading: false');
      // #endregion
      
      // STEP 6: Гарантируем сохранение в Hive кэш (на случай если репозиторий не сохранил)
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        await localDataSource.cacheMessages(chatId, syncedMessages);
      } catch (e) {
        print('[MSG_LOAD] Failed to cache messages in Hive: $e');
      }
      
      // STEP 7: Trigger sync of pending messages if connected
      // This ensures stuck messages are retried when user opens the chat
      if (pendingMessages.isNotEmpty && _isSignalRConnected) {
        print('[MSG_LOAD] Triggering sync of ${pendingMessages.length} pending messages');
        try {
          final outboxSyncService = _ref.read(outboxSyncServiceProvider);
          // Don't await - sync happens in background
          outboxSyncService.syncMessagesForChat(chatId);
        } catch (e) {
          print('[MSG_LOAD] Failed to trigger outbox sync: $e');
        }
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
      
      // Enqueue chat preview update via sync service
      try {
        final syncService = _ref.read(chatPreviewSyncServiceProvider);
        syncService.enqueueUpdate(ChatPreviewUpdate(
          chatId: chatId,
          lastMessage: localMessage,
          unreadCountDelta: null, // Don't increment for own messages
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        print('[MSG_SEND] Failed to enqueue chat preview update: $e');
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
      // #region agent log - Hypothesis B: Track sync attempts and SignalR status
      print('[MSG_SYNC] HYP_B1: Syncing message to backend - localId: $localId, type: $type, outboxId: $outboxId, attempt: ${attemptNumber + 1}/$maxAttempts, signalRConnected: $_isSignalRConnected, timestamp: ${DateTime.now().toIso8601String()}');
      // #endregion
      print('[MSG_SEND] Syncing message to backend: localId=$localId, outboxId=$outboxId (attempt ${attemptNumber + 1}/$maxAttempts)');
      if (outboxId != null) {
        await _outboxRepository.markAsSyncing(outboxId);
      }
      
      // Send via API with clientMessageId for idempotency
      final Message serverMessage;
      // #region agent log - Hypothesis B: Track API call timing
      final apiCallStart = DateTime.now();
      // #endregion
      if (type == MessageType.text) {
        // Try to encrypt the message if encryption is available
        String? contentToSend = content;
        bool isEncrypted = false;
        
        if (content != null && _otherParticipantPublicKey != null && _otherParticipantPublicKey!.isNotEmpty) {
          try {
            final encrypted = await _encryptContent(content);
            if (encrypted != null) {
              contentToSend = encrypted;
              isEncrypted = true;
              print('[MSG_SEND] Message encrypted for sending');
            }
          } catch (e) {
            print('[MSG_SEND] Encryption failed, sending unencrypted: $e');
          }
        }
        
        serverMessage = await _messageRepository.sendMessage(
          chatId: chatId,
          type: type,
          content: contentToSend,
          clientMessageId: clientMessageId,
          isEncrypted: isEncrypted,
        );
      } else {
        serverMessage = await _messageRepository.sendAudioMessage(
          chatId: chatId,
          audioPath: audioPath!,
          clientMessageId: clientMessageId,
        );
      }
      // #region agent log - Hypothesis B
      final apiCallDuration = DateTime.now().difference(apiCallStart).inMilliseconds;
      print('[MSG_SYNC] HYP_B2: API call completed in ${apiCallDuration}ms, serverId: ${serverMessage.id}');
      // #endregion
      
      print('[MSG_SEND] Message synced successfully. Server ID: ${serverMessage.id}, Status: ${serverMessage.status}');
      
      // IMPORTANT: Ensure status is at least 'sent' after successful sync
      // Server might return 'sending', but we know it's sent successfully
      final finalStatus = serverMessage.status == MessageStatus.sending 
          ? MessageStatus.sent 
          : serverMessage.status;
      
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
      
      // Register ID mapping for future lookups
      _registerIdMapping(localId, serverMessage.id);
      
      // Update message in UI: replace local ID with server ID and update status
      final messageIndex = _findMessageIndex(localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        final finalServerMessage = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
          status: finalStatus, // Ensure proper status
        );
        updatedMessages[messageIndex] = finalServerMessage;
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Message updated in UI with server ID: ${serverMessage.id}, status: $finalStatus');
        
        // FORCE update status to ensure UI reflects the change
        // This is a safety net in case the state update didn't trigger rebuild
        updateMessageStatus(serverMessage.id, finalStatus, force: true);
        
        // Track for outgoing status polling (fallback if SignalR misses status update)
        _trackSentMessage(serverMessage.id);
        
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
      } else {
        print('[MSG_SEND] ⚠️ Message not found for update: localId=$localId, serverId=${serverMessage.id}');
        // Still register the mapping for future reference
      }
      
    } catch (e) {
      // #region agent log - Hypothesis B: Track sync failures
      print('[MSG_SYNC] HYP_B_ERROR: Sync failed (attempt ${attemptNumber + 1}) - localId: $localId, error: $e');
      // #endregion
      print('[MSG_SEND] Failed to sync message to backend (attempt ${attemptNumber + 1}): $e');
      
      // Check if we should retry
      if (attemptNumber < maxAttempts - 1) {
        // Calculate backoff delay
        final delaySeconds = attemptNumber < backoffDelays.length 
            ? backoffDelays[attemptNumber] 
            : backoffDelays.last;
        
        // #region agent log - Hypothesis B
        print('[MSG_SYNC] HYP_B3: Will retry in ${delaySeconds}s');
        // #endregion
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
        // #region agent log - Hypothesis B
        print('[MSG_SYNC] HYP_B_MAX_RETRY: Max retry attempts reached for message: $localId');
        // #endregion
        print('[MSG_SEND] Max retry attempts reached for message: $localId');
        _pendingSends.remove(localId);
        await _outboxRepository.markAsFailed(localId, 'Failed after $maxAttempts attempts: ${e.toString()}');
        
        // Update message status to failed in UI using improved lookup
        final messageIndex = _findMessageIndex(localId);
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
      // #region agent log - Hypothesis B: Check clientMessageId for image
      print('[MSG_SYNC] HYP_B_IMAGE: Syncing image to backend - localId: $localId, clientMessageId: $clientMessageId, attempt: ${attemptNumber + 1}/$maxAttempts');
      // #endregion
      print('[MSG_SEND] Syncing image to backend: $localId (attempt ${attemptNumber + 1}/$maxAttempts)');
      
      // Send via API with clientMessageId
      final serverMessage = await _messageRepository.sendImageMessage(
        chatId: chatId,
        imagePath: imagePath,
        clientMessageId: clientMessageId,
      );
      
      print('[MSG_SEND] Image synced successfully. Server ID: ${serverMessage.id}, Status: ${serverMessage.status}');
      
      // IMPORTANT: Ensure status is at least 'sent' after successful sync
      // Server might return 'sending', but we know it's sent successfully
      final finalStatus = serverMessage.status == MessageStatus.sending 
          ? MessageStatus.sent 
          : serverMessage.status;
      
      // Remove from pending sends
      _pendingSends.remove(localId);
      
      // IMMEDIATELY remove from outbox after successful sync
      await _outboxRepository.removePendingMessage(localId);
      print('[MSG_SEND] Removed image message from outbox: $localId');
      
      // Register ID mapping for future lookups
      _registerIdMapping(localId, serverMessage.id);
      
      // Update message in UI: replace local ID with server ID and update status
      final messageIndex = _findMessageIndex(localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        final finalServerMessage = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
          status: finalStatus, // Ensure proper status
        );
        updatedMessages[messageIndex] = finalServerMessage;
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Image message updated in UI with server ID: ${serverMessage.id}, status: $finalStatus');
        
        // FORCE update status to ensure UI reflects the change
        updateMessageStatus(serverMessage.id, finalStatus, force: true);
        
        // Track for outgoing status polling (fallback if SignalR misses status update)
        _trackSentMessage(serverMessage.id);
        
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
      } else {
        print('[MSG_SEND] ⚠️ Image message not found for update: localId=$localId, serverId=${serverMessage.id}');
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
        
        // Update message status to failed in UI using improved lookup
        final messageIndex = _findMessageIndex(localId);
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
      
      // STEP 3: Cache audio locally so it can be played offline even after sending
      try {
        final audioStorageService = _ref.read(audioStorageServiceProvider);
        final cachedPath = await audioStorageService.cacheSentAudio(localId, audioPath);
        if (cachedPath != null) {
          print('[MSG_SEND] Audio cached locally for offline playback: $localId');
        }
      } catch (e) {
        print('[MSG_SEND] Failed to cache sent audio (non-critical): $e');
      }
      
      // STEP 4: Add to outbox queue for persistence
      final outboxEntry = await _outboxRepository.addToOutbox(
        chatId: chatId,
        type: MessageType.audio,
        localAudioPath: audioPath,
      );
      final outboxId = outboxEntry.localId; // Save outbox ID for later cleanup
      
      // STEP 5: Send to backend asynchronously with clientMessageId
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
      
      // STEP 3: Cache image locally so it can be viewed offline even after sending
      try {
        final imageStorageService = _ref.read(imageStorageServiceProvider);
        final cachedPath = await imageStorageService.saveLocalImage(localId, imagePath);
        if (cachedPath != null) {
          print('[MSG_SEND] Image cached locally for offline viewing: $localId');
        }
      } catch (e) {
        print('[MSG_SEND] Failed to cache sent image (non-critical): $e');
      }
      
      // STEP 4: Send to backend asynchronously with clientMessageId
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

  /// Send a file message (max 20MB)
  Future<void> sendFileMessage(String filePath, String fileName) async {
    print('[MSG_SEND] Starting local-first send for file message: $fileName');
    
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastSendTime = now;
    
    state = state.copyWith(isSending: true);
    String? localId;
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get file size
      final file = File(filePath);
      final fileSize = await file.length();
      
      // Check file size limit (20MB)
      if (fileSize > 20 * 1024 * 1024) {
        throw Exception('Размер файла не должен превышать 20 МБ');
      }
      
      localId = _uuid.v4();
      final clientMessageId = localId;
      
      if (_pendingSends.contains(localId)) {
        state = state.copyWith(isSending: false);
        return;
      }
      
      _pendingSends.add(localId);
      
      final localMessage = Message(
        id: localId,
        chatId: chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.file,
        localFilePath: filePath,
        originalFileName: fileName,
        fileSize: fileSize,
        status: MessageStatus.sending,
        createdAt: now,
        localId: localId,
        isLocalOnly: true,
        clientMessageId: clientMessageId,
      );
      
      // Add to UI immediately
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      print('[MSG_SEND] File message added to UI with local ID: $localId');
      
      _cache.put(localMessage);
      
      // Update chat preview
      try {
        _ref.read(chatsProvider.notifier).updateChatLastMessage(
          chatId, 
          localMessage, 
          incrementUnread: false,
        );
      } catch (e) {
        print('[MSG_SEND] Failed to update chat preview: $e');
      }
      
      // Sync to backend
      _syncFileToBackend(localId, filePath, fileName, clientMessageId: clientMessageId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to send file message: $e');
      if (localId != null) {
        _pendingSends.remove(localId);
      }
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _syncFileToBackend(String localId, String filePath, String fileName, {String? clientMessageId, int attemptNumber = 0}) async {
    const maxAttempts = 5;
    final backoffDelays = [1, 2, 4, 8, 16];
    
    try {
      print('[MSG_SEND] Syncing file to backend: $localId (attempt ${attemptNumber + 1}/$maxAttempts)');
      
      final serverMessage = await _messageRepository.sendFileMessage(
        chatId: chatId,
        filePath: filePath,
        fileName: fileName,
        clientMessageId: clientMessageId,
      );
      
      print('[MSG_SEND] File synced successfully. Server ID: ${serverMessage.id}');
      
      final finalStatus = serverMessage.status == MessageStatus.sending 
          ? MessageStatus.sent 
          : serverMessage.status;
      
      _pendingSends.remove(localId);
      _registerIdMapping(localId, serverMessage.id);
      
      // Update message in UI
      final messageIndex = _findMessageIndex(localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        final finalServerMessage = serverMessage.copyWith(
          localId: localId,
          localFilePath: filePath, // Keep local path for viewing
          isLocalOnly: false,
          status: finalStatus,
        );
        updatedMessages[messageIndex] = finalServerMessage;
        state = state.copyWith(messages: updatedMessages);
        
        updateMessageStatus(serverMessage.id, finalStatus, force: true);
        _trackSentMessage(serverMessage.id);
        
        try {
          _ref.read(chatsProvider.notifier).updateChatLastMessage(
            chatId, 
            finalServerMessage, 
            incrementUnread: false,
          );
        } catch (e) {
          print('[MSG_SEND] Failed to update chat preview: $e');
        }
      }
      
    } catch (e) {
      print('[MSG_SEND] Failed to sync file to backend (attempt ${attemptNumber + 1}): $e');
      
      if (attemptNumber < maxAttempts - 1) {
        final delaySeconds = attemptNumber < backoffDelays.length 
            ? backoffDelays[attemptNumber] 
            : backoffDelays.last;
        
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            _syncFileToBackend(localId, filePath, fileName, clientMessageId: clientMessageId, attemptNumber: attemptNumber + 1);
          }
        });
      } else {
        _pendingSends.remove(localId);
        
        final messageIndex = _findMessageIndex(localId);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            status: MessageStatus.failed,
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
    }
  }

  void addMessage(Message message) {
    // Проверяем, что сообщение для этого чата
    if (message.chatId != chatId) {
      return;
    }
    
    print('[MSG_RECV] Received message via SignalR: ${message.id} (clientMessageId: ${message.clientMessageId ?? 'none'})');
    // #region agent log - Hypothesis A/D: Track incoming message
    print('[MSG_RECV] HYP_A_INCOMING: Message received - id: ${message.id}, clientMessageId: ${message.clientMessageId}, type: ${message.type}, isLocalOnly: ${message.isLocalOnly}, currentMessages: ${state.messages.length}');
    // #endregion
    
    // Handle encrypted messages asynchronously
    if (message.isEncrypted && message.type == MessageType.text) {
      _addEncryptedMessage(message);
      return;
    }
    
    // Check if this is a replacement for a local message
    // (when our own message comes back from server via SignalR)
    final profileState = _ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    final isFromMe = currentUserId != null && message.senderId == currentUserId;
    
    // If message is from me, check if we have a local version to replace
    if (isFromMe && message.clientMessageId != null && message.clientMessageId!.isNotEmpty) {
      // Only match by clientMessageId - most reliable method
      final localIndex = state.messages.indexWhere((m) => 
        m.localId == message.clientMessageId || 
        m.clientMessageId == message.clientMessageId ||
        m.id == message.clientMessageId // Also check message id (for pending messages)
      );
      
      if (localIndex != -1) {
        print('[MSG_RECV] Found local message by clientMessageId: ${message.clientMessageId}');
        
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
        
        // Register ID mapping for future lookups
        if (localMessage.localId != null) {
          _registerIdMapping(localMessage.localId!, message.id);
        }
        if (message.clientMessageId != null) {
          _registerIdMapping(message.clientMessageId!, message.id);
        }
        
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
      
      // Enqueue chat preview update via sync service
      try {
        final profileState = _ref.read(profileProvider);
        final isFromMe = message.senderId == profileState.profile?.id;
        
        final syncService = _ref.read(chatPreviewSyncServiceProvider);
        syncService.enqueueUpdate(ChatPreviewUpdate(
          chatId: chatId,
          lastMessage: message,
          unreadCountDelta: isFromMe ? null : 1, // Increment for messages from others
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        print('[MSG_RECV] Failed to enqueue chat preview update: $e');
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
        audioUrl.startsWith('http') ? audioUrl : 'https://messenger.rare-books.ru$audioUrl'
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

  /// Get priority of message status (higher = more final)
  /// Used to prevent race conditions where a "lower" status overwrites a "higher" one
  int _getStatusPriority(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.failed:
        return 1; // Same as sent - user can retry
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
      case MessageStatus.played:
        return 4; // Highest for audio messages
    }
  }

  void updateMessageStatus(String messageId, MessageStatus status, {bool force = false}) {
    // #region agent log
    print('[MSG_STATUS] HYP_CLIENT: updateMessageStatus called - MessageId: $messageId, NewStatus: $status, ChatId: $chatId, Force: $force, Timestamp: ${DateTime.now().toIso8601String()}');
    // #endregion
    
    // Use improved message lookup that checks id, localId, and mapping
    final messageIndex = _findMessageIndex(messageId);
    // #region agent log
    print('[MSG_STATUS] HYP_CLIENT: Message found at index: $messageIndex (searched by id, localId, and mapping)');
    // #endregion
    if (messageIndex != -1) {
      final updatedMessages = [...state.messages];
      final oldMessage = updatedMessages[messageIndex];
      final oldStatus = oldMessage.status;
      // #region agent log
      print('[MSG_STATUS] HYP_CLIENT: Old status: $oldStatus, New status: $status, SenderId: ${oldMessage.senderId}');
      // #endregion
      
      // Prevent race condition: don't downgrade status unless forced
      // e.g., don't overwrite 'delivered' with 'sent' if SignalR already updated it
      final oldPriority = _getStatusPriority(oldStatus);
      final newPriority = _getStatusPriority(status);
      
      if (!force && newPriority < oldPriority) {
        print('[MSG_STATUS] Ignoring status downgrade: $oldStatus (priority $oldPriority) -> $status (priority $newPriority)');
        return;
      }
      
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
        
        // Remove from tracking only if status is fully final (read or played)
        // Keep 'delivered' in tracking to continue polling for 'read' status
        if (status == MessageStatus.read ||
            status == MessageStatus.played) {
          _recentlySentMessages.remove(messageId);
        }
        
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
      print('[STATUS_UPDATE] markMessagesAsRead called for chat $chatId');
      
      // Get current user ID
      final profileState = _ref.read(profileProvider);
      final currentUserId = profileState.userId;
      
      if (currentUserId == null) {
        print('[STATUS_UPDATE] currentUserId is null, returning');
        return;
      }
      
      // Cancel push notifications for this chat
      try {
        final notificationService = _ref.read(notificationServiceProvider);
        await notificationService.cancelNotificationsForChat(chatId);
      } catch (e) {
        print('[STATUS_UPDATE] Failed to cancel notifications: $e');
      }
      
      // Find unread messages from other users (exclude read AND played - played implies read)
      final unreadMessages = state.messages.where((message) {
        return message.senderId != currentUserId && 
               message.status != MessageStatus.read &&
               message.status != MessageStatus.played;
      }).toList();
      
      print('[STATUS_UPDATE] Found ${unreadMessages.length} unread messages');
      
      if (unreadMessages.isEmpty) {
        // Even if no unread messages, clear the unread count to ensure sync
        _ref.read(chatsProvider.notifier).clearUnreadCount(chatId);
        return;
      }
      
      // Update local status immediately for responsive UI
      for (final message in unreadMessages) {
        updateMessageStatus(message.id, MessageStatus.read);
      }
      
      // Clear unread count immediately
      _ref.read(chatsProvider.notifier).clearUnreadCount(chatId);
      
      // Send batch request via REST API (single request instead of multiple SignalR calls)
      // REST API will trigger SignalR notifications to sender
      try {
        final messageIds = unreadMessages.map((m) => m.id).toList();
        await _messageRepository.batchMarkAsRead(messageIds);
        print('[STATUS_UPDATE] Batch read confirmation sent via REST API for ${messageIds.length} messages');
      } catch (e) {
        print('[STATUS_UPDATE] Failed to send batch read via REST API: $e');
        // Add to queue for retry
        for (final message in unreadMessages) {
          await _statusQueue.enqueueStatusUpdate(message.id, MessageStatus.read);
        }
      }
    } catch (e) {
      print('[STATUS_UPDATE] Failed to mark messages as read: $e');
    }
  }

  Future<void> markAudioAsPlayed(String messageId) async {
    try {
      print('[AUDIO_STATUS] Marking audio as played: $messageId');
      
      // Update UI immediately
      updateMessageStatus(messageId, MessageStatus.played);
      
      // CRITICAL: Force save to Hive cache before API call
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        await localDataSource.updateMessageStatus(chatId, messageId, MessageStatus.played);
        print('[AUDIO_STATUS] Status saved to Hive cache');
      } catch (e) {
        print('[AUDIO_STATUS] Failed to save to Hive: $e');
      }
      
      // Add to status queue for reliable API sync
      await _statusQueue.enqueueStatusUpdate(messageId, MessageStatus.played);
      
      // Try immediate API call
      try {
        await _signalRService.markAudioAsPlayed(messageId, chatId);
        print('[AUDIO_STATUS] Status sent to server via SignalR');
      } catch (e) {
        print('[AUDIO_STATUS] SignalR failed, queue will retry: $e');
      }
    } catch (e) {
      print('[AUDIO_STATUS] Failed to mark audio as played: $e');
      // Don't rethrow - queue will handle it
    }
  }
  
  /// Merge messages from server with cached messages, preserving local 'played' status
  /// This prevents the server from overwriting locally tracked audio playback status
  List<Message> _mergeMessagesPreservingPlayedStatus(
    List<Message> cached,
    List<Message> fromServer
  ) {
    final Map<String, Message> cachedMap = {
      for (var msg in cached) msg.id: msg
    };
    
    return fromServer.map((serverMsg) {
      final cachedMsg = cachedMap[serverMsg.id];
      
      // If cached message has 'played' status, keep it
      if (cachedMsg != null && 
          cachedMsg.status == MessageStatus.played &&
          serverMsg.status != MessageStatus.played) {
        print('[MSG_LOAD] Preserving played status for message ${serverMsg.id}');
        return serverMsg.copyWith(status: MessageStatus.played);
      }
      
      return serverMsg;
    }).toList();
  }

  /// Merge messages with Hive-cached statuses to preserve played status
  /// This is used when LRU cache is empty (e.g., after exiting and re-entering chat)
  List<Message> _mergeMessagesWithHiveStatuses(
    List<Message> messages,
    Map<String, MessageStatus> hiveStatuses
  ) {
    return messages.map((msg) {
      final hiveStatus = hiveStatuses[msg.id];
      
      // If Hive has 'played' status and server doesn't, preserve the Hive status
      if (hiveStatus == MessageStatus.played && msg.status != MessageStatus.played) {
        print('[MSG_LOAD] Restoring played status from Hive for message ${msg.id}');
        return msg.copyWith(status: MessageStatus.played);
      }
      
      return msg;
    }).toList();
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
    if (_isLoadingOlder || state.isLoading || state.isLoadingOlder) {
      print('[MSG_LOAD] Already loading, skipping...');
      return;
    }
    
    // Check if we already know there are no more messages
    if (!state.hasMoreOlder) {
      print('[MSG_LOAD] No more older messages available');
      return;
    }

    _isLoadingOlder = true;
    state = state.copyWith(isLoadingOlder: true);
    
    try {
      // Get the oldest message as cursor
      if (state.messages.isEmpty) {
        print('[MSG_LOAD] No messages to use as cursor');
        _isLoadingOlder = false;
        state = state.copyWith(isLoadingOlder: false, hasMoreOlder: false);
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
        state = state.copyWith(isLoadingOlder: false, hasMoreOlder: false);
        return;
      }
      
      print('[MSG_LOAD] Loaded ${olderMessages.length} older messages');
      
      // Merge with current messages (avoid duplicates)
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages = olderMessages.where((m) => !existingIds.contains(m.id)).toList();
      
      if (newMessages.isEmpty) {
        print('[MSG_LOAD] All loaded messages were duplicates');
        _isLoadingOlder = false;
        state = state.copyWith(isLoadingOlder: false, hasMoreOlder: false);
        return;
      }
      
      // Prepend older messages to current list
      final List<Message> allMessages = [...newMessages, ...state.messages];
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Update LRU cache
      _cache.putAll(newMessages);
      
      // Determine if there might be more messages
      final hasMore = olderMessages.length >= 30;
      
      state = state.copyWith(
        messages: allMessages,
        isLoadingOlder: false,
        hasMoreOlder: hasMore,
      );
      
      print('[MSG_LOAD] Cursor pagination completed: added ${newMessages.length} messages, hasMoreOlder: $hasMore');
    } catch (e) {
      print('[MSG_LOAD] Failed to load older messages: $e');
      state = state.copyWith(
        isLoadingOlder: false,
        error: e.toString(),
      );
    } finally {
      _isLoadingOlder = false;
    }
  }

  /// Check if there are potentially more older messages to load
  bool get canLoadMore => state.hasMoreOlder;
  
  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      print('[MSG_DELETE] Deleting message: $messageId');
      
      // Optimistic removal from UI
      final updatedMessages = state.messages.where((m) => m.id != messageId).toList();
      state = state.copyWith(messages: updatedMessages);
      
      // Delete on server
      await _messageRepository.deleteMessage(messageId);
      
      // Remove from LRU cache
      _cache.remove(messageId);
      
      print('[MSG_DELETE] Message deleted successfully');
    } catch (e) {
      print('[MSG_DELETE] Failed to delete message: $e');
      // Reload messages to restore the deleted one if server delete failed
      loadMessages();
    }
  }
  
  /// Edit a text message
  Future<void> editMessage(String messageId, String newContent) async {
    try {
      print('[MSG_EDIT] Editing message: $messageId');
      
      // Find the message
      final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
      if (messageIndex == -1) {
        throw Exception('Message not found');
      }
      
      final message = state.messages[messageIndex];
      if (message.type != MessageType.text) {
        throw Exception('Can only edit text messages');
      }
      
      // Optimistic update
      final updatedMessage = message.copyWith(
        content: newContent,
        isEdited: true,
        editedAt: DateTime.now(),
      );
      
      final updatedMessages = [...state.messages];
      updatedMessages[messageIndex] = updatedMessage;
      state = state.copyWith(messages: updatedMessages);
      
      // Update on server
      await _messageRepository.editMessage(messageId, newContent);
      
      // Update LRU cache
      _cache.update(updatedMessage);
      
      print('[MSG_EDIT] Message edited successfully');
    } catch (e) {
      print('[MSG_EDIT] Failed to edit message: $e');
      // Reload to restore original
      loadMessages();
    }
  }
  
  /// Forward a message to another chat
  Future<void> forwardMessage({
    required Message originalMessage,
    required String targetChatId,
  }) async {
    try {
      print('[MSG_FORWARD] Forwarding message ${originalMessage.id} to chat $targetChatId');
      
      await _messageRepository.forwardMessage(
        originalMessageId: originalMessage.id,
        targetChatId: targetChatId,
      );
      
      print('[MSG_FORWARD] Message forwarded successfully');
    } catch (e) {
      print('[MSG_FORWARD] Failed to forward message: $e');
      rethrow;
    }
  }
  
  /// Send a message with reply
  Future<void> sendMessageWithReply(String content, Message replyToMessage) async {
    print('[MSG_SEND] Starting local-first send for text message with reply');
    
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!).inMilliseconds < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastSendTime = now;
    
    state = state.copyWith(isSending: true);
    String? localId;
    
    try {
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      localId = _uuid.v4();
      
      if (_pendingSends.contains(localId)) {
        state = state.copyWith(isSending: false);
        return;
      }
      
      _pendingSends.add(localId);
      
      // Create ReplyMessage from the original message
      final replyInfo = ReplyMessage(
        id: replyToMessage.id,
        senderId: replyToMessage.senderId,
        senderName: replyToMessage.senderName,
        type: replyToMessage.type,
        content: replyToMessage.content,
        originalFileName: replyToMessage.originalFileName,
      );
      
      final localMessage = Message(
        id: localId,
        chatId: chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.text,
        content: content,
        replyToMessageId: replyToMessage.id,
        replyToMessage: replyInfo,
        status: MessageStatus.sending,
        createdAt: now,
        localId: localId,
        isLocalOnly: true,
      );
      
      // Add to UI immediately
      final updatedMessages = [...state.messages, localMessage];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: updatedMessages, isSending: false);
      
      _cache.put(localMessage);
      
      // Send to backend
      _syncMessageWithReplyToBackend(localId, content, replyToMessage.id, clientMessageId: localId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to create local message with reply: $e');
      if (localId != null) {
        _pendingSends.remove(localId);
      }
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }
  
  Future<void> _syncMessageWithReplyToBackend(
    String localId,
    String content,
    String replyToMessageId, {
    String? clientMessageId,
    int attemptNumber = 0,
  }) async {
    const maxAttempts = 5;
    
    try {
      final serverMessage = await _messageRepository.sendMessageWithReply(
        chatId: chatId,
        content: content,
        replyToMessageId: replyToMessageId,
        clientMessageId: clientMessageId,
      );
      
      print('[MSG_SEND] Message with reply synced successfully. Server ID: ${serverMessage.id}');
      
      // Update local message with server response
      final messageIndex = _findMessageIndex(localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        updatedMessages[messageIndex] = serverMessage.copyWith(
          localId: localId,
          isLocalOnly: false,
        );
        state = state.copyWith(messages: updatedMessages);
        _cache.update(updatedMessages[messageIndex]);
      }
      
      _pendingSends.remove(localId);
      
    } catch (e) {
      print('[MSG_SEND] Failed to sync message with reply: $e (attempt ${attemptNumber + 1}/$maxAttempts)');
      
      if (attemptNumber < maxAttempts - 1) {
        final delaySeconds = [1, 2, 4, 8, 16][attemptNumber];
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            _syncMessageWithReplyToBackend(localId, content, replyToMessageId, 
                clientMessageId: clientMessageId, attemptNumber: attemptNumber + 1);
          }
        });
      } else {
        _pendingSends.remove(localId);
        final messageIndex = _findMessageIndex(localId);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            status: MessageStatus.failed,
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
    }
  }
  
  /// Handle message edited event from SignalR
  void handleMessageEdited(String messageId, String newContent, DateTime editedAt) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final updatedMessages = [...state.messages];
      updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
        content: newContent,
        isEdited: true,
        editedAt: editedAt,
      );
      state = state.copyWith(messages: updatedMessages);
      print('[MSG_EDIT] Updated message from SignalR: $messageId');
    }
  }
  
  /// Handle message deleted event from SignalR
  void handleMessageDeleted(String messageId) {
    final updatedMessages = state.messages.where((m) => m.id != messageId).toList();
    if (updatedMessages.length != state.messages.length) {
      state = state.copyWith(messages: updatedMessages);
      _cache.remove(messageId);
      print('[MSG_DELETE] Removed message from SignalR: $messageId');
    }
  }
  
  /// Update local file path for a message (used after downloading files)
  void updateMessageLocalPath(String messageId, {String? localFilePath, String? localAudioPath, String? localImagePath}) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;
    
    final updatedMessages = [...state.messages];
    updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
      localFilePath: localFilePath,
      localAudioPath: localAudioPath,
      localImagePath: localImagePath,
    );
    
    state = state.copyWith(messages: updatedMessages);
    _cache.update(updatedMessages[messageIndex]);
    print('[MSG_UPDATE] Updated local path for message: $messageId');
  }
}


