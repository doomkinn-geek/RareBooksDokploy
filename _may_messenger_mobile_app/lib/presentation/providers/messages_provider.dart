import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message_model.dart';
import '../../data/services/message_sync_service.dart';
import '../../core/services/logger_service.dart';
import 'auth_provider.dart';
import 'signalr_provider.dart';
import 'profile_provider.dart';

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    // Keep the provider alive even when not used
    ref.keepAlive();
    return MessagesNotifier(
      ref.read(messageRepositoryProvider),
      ref.read(outboxRepositoryProvider),
      chatId,
      ref.read(signalRServiceProvider),
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
  final Ref _ref;
  final _uuid = const Uuid();
  late final MessageSyncService _syncService;
  bool _isSignalRConnected = true;

  MessagesNotifier(
    this._messageRepository,
    this._outboxRepository,
    this.chatId,
    this._signalRService,
    this._ref,
  ) : super(MessagesState()) {
    _syncService = MessageSyncService(_messageRepository);
    loadMessages();
    _monitorSignalRConnection();
  }

  /// Monitor SignalR connection state and start/stop polling as needed
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
          print('[SYNC] SignalR connected, stopping status polling for chat: $chatId');
          _syncService.stopPolling();
          // Trigger a final sync to catch any missed updates
          _syncService.syncNow(
            chatId: chatId,
            onStatusUpdate: (messageId, status) {
              updateMessageStatus(messageId, status);
            },
          );
        }
      }
      
      // Continue monitoring
      _monitorSignalRConnection();
    });
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  Future<void> loadMessages({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Load synced messages from repository (cache or API)
      final List<Message> syncedMessages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      
      // Load pending messages from outbox
      final pendingMessages = await _outboxRepository.getPendingMessagesForChat(chatId);
      final profileState = _ref.read(profileProvider);
      final currentUser = profileState.profile;
      
      // Convert pending messages to Message objects
      final List<Message> localMessages = pendingMessages
          .map((pm) => pm.toMessage(
                currentUser?.id ?? '',
                currentUser?.displayName ?? 'Me',
              ))
          .toList();
      
      // Merge synced and local messages, removing duplicates
      final allMessages = <String, Message>{};
      
      // Add synced messages first
      for (final msg in syncedMessages) {
        allMessages[msg.id] = msg;
      }
      
      // Add local messages (they won't override synced ones with same ID)
      for (final msg in localMessages) {
        if (!allMessages.containsKey(msg.id)) {
          allMessages[msg.id] = msg;
        }
      }
      
      // Convert to list and sort by date
      final messages = allMessages.values.toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      print('[MSG_SEND] Loaded ${messages.length} messages (${syncedMessages.length} synced + ${localMessages.length} local)');
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
      
      // Гарантируем сохранение в кэш (на случай если репозиторий не сохранил)
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        await localDataSource.cacheMessages(chatId, syncedMessages);
      } catch (e) {
        print('[MessagesProvider] Failed to cache messages: $e');
      }
    } catch (e) {
      print('[MessagesProvider] Load messages error: $e');
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
  
  /// Sync a local message to the backend
  Future<void> _syncMessageToBackend(String localId, MessageType type, {String? content, String? audioPath}) async {
    try {
      print('[MSG_SEND] Syncing message to backend: $localId');
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
      print('[MSG_SEND] Failed to sync message to backend: $e');
      
      // Mark as failed in outbox
      await _outboxRepository.markAsFailed(localId, e.toString());
      
      // Update message status to failed in UI
      final messageIndex = state.messages.indexWhere((m) => m.id == localId);
      if (messageIndex != -1) {
        final updatedMessages = [...state.messages];
        updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
          status: MessageStatus.failed,
        );
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_SEND] Message marked as failed in UI: $localId');
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
        updatedMessages[localIndex] = message.copyWith(
          localId: localMessage.localId,
          isLocalOnly: false,
        );
        state = state.copyWith(messages: updatedMessages);
        print('[MSG_RECV] Replaced local message with server message: ${message.id}');
        
        // Clean up outbox if we have a local ID
        if (localMessage.localId != null) {
          _outboxRepository.markAsSynced(localMessage.localId!, message.id);
        }
        
        // Cache the server message
        try {
          final localDataSource = _ref.read(localDataSourceProvider);
          localDataSource.addMessageToCache(chatId, message);
        } catch (e) {
          print('[MSG_RECV] Failed to cache message: $e');
        }
        return;
      }
    }
    
    // Check if message already exists by ID
    final exists = state.messages.any((m) => m.id == message.id);
    
    if (!exists) {
      // Add new message and sort by date
      final newMessages = [...state.messages, message];
      newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        messages: newMessages,
      );
      
      print('[MSG_RECV] Added new message to state: ${message.id}');
      
      // Save message to cache for persistence
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        localDataSource.addMessageToCache(chatId, message);
      } catch (e) {
        print('[MSG_RECV] Failed to cache message: $e');
      }
      
      // Background download for audio messages
      if (message.type == MessageType.audio && 
          message.filePath != null && 
          message.filePath!.isNotEmpty) {
        _downloadAudioInBackground(message);
      }
    } else {
      print('[MSG_RECV] Message already exists, ignoring: ${message.id}');
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
      updatedMessages[messageIndex] = oldMessage.copyWith(status: status);
      
      state = state.copyWith(messages: updatedMessages);
        
        print('[MessagesProvider] Message status updated in chatId=$chatId: messageId=$messageId, $oldStatus -> $status');
        
        // Сохраняем обновленный статус в кэш
        try {
          final localDataSource = _ref.read(localDataSourceProvider);
          localDataSource.updateMessageStatus(chatId, messageId, status);
          print('[MessagesProvider] Message status cached: $messageId -> $status');
        } catch (e) {
          print('[MessagesProvider] Failed to cache message status: $e');
        }
      } else {
        print('[MessagesProvider] Message status unchanged for messageId=$messageId: $status');
      }
    } else {
      print('[MessagesProvider] Message not found for status update: messageId=$messageId in chatId=$chatId');
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
}


