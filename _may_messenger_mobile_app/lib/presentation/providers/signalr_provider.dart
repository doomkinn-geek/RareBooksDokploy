import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_service.dart';
import '../../data/models/message_model.dart';
import 'auth_provider.dart';
import 'messages_provider.dart';
import 'chats_provider.dart';
import 'contacts_names_provider.dart';
import 'profile_provider.dart';
import 'typing_provider.dart';
import 'online_status_provider.dart';
import '../../core/services/notification_service.dart';

final signalRServiceProvider = Provider<SignalRService>((ref) {
  return SignalRService();
});

/// Global cache for message status updates received when MessagesProvider is not initialized
/// This ensures status updates are not lost when user is not viewing the chat
final pendingStatusUpdatesProvider = StateNotifierProvider<PendingStatusUpdatesNotifier, Map<String, MessageStatus>>((ref) {
  return PendingStatusUpdatesNotifier();
});

class PendingStatusUpdatesNotifier extends StateNotifier<Map<String, MessageStatus>> {
  PendingStatusUpdatesNotifier() : super({});
  
  /// Cache a status update for later application
  void cacheStatusUpdate(String messageId, MessageStatus status) {
    // Only cache if it's a higher priority status
    final existingStatus = state[messageId];
    if (existingStatus == null || _getStatusPriority(status) > _getStatusPriority(existingStatus)) {
      state = {...state, messageId: status};
      print('[STATUS_CACHE] Cached status update: $messageId -> $status');
    }
  }
  
  /// Get and remove pending status update for a message
  MessageStatus? consumeStatusUpdate(String messageId) {
    final status = state[messageId];
    if (status != null) {
      state = Map.from(state)..remove(messageId);
      print('[STATUS_CACHE] Consumed cached status for $messageId: $status');
    }
    return status;
  }
  
  /// Get all pending updates for messages in a chat (by message IDs)
  Map<String, MessageStatus> consumeStatusUpdatesForMessages(List<String> messageIds) {
    final result = <String, MessageStatus>{};
    final newState = Map<String, MessageStatus>.from(state);
    
    for (final messageId in messageIds) {
      if (newState.containsKey(messageId)) {
        result[messageId] = newState[messageId]!;
        newState.remove(messageId);
      }
    }
    
    if (result.isNotEmpty) {
      state = newState;
      print('[STATUS_CACHE] Consumed ${result.length} cached status updates');
    }
    
    return result;
  }
  
  /// Clean up old entries (call periodically)
  void cleanup() {
    // Keep only last 1000 entries to prevent memory issues
    if (state.length > 1000) {
      final entries = state.entries.toList();
      final trimmed = entries.skip(entries.length - 500).toList();
      state = Map.fromEntries(trimmed);
      print('[STATUS_CACHE] Cleaned up cache, ${state.length} entries remaining');
    }
  }
  
  int _getStatusPriority(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.failed:
        return 1;
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
      case MessageStatus.played:
        return 4;
    }
  }
}

final signalRConnectionProvider = StateNotifierProvider<SignalRConnectionNotifier, SignalRConnectionState>((ref) {
  return SignalRConnectionNotifier(
    ref.read(signalRServiceProvider),
    ref.read(authRepositoryProvider),
    ref,
  );
});

class SignalRConnectionState {
  final bool isConnected;
  final bool isReconnecting; // Visible reconnecting (shows banner)
  final bool isSilentReconnecting; // Silent reconnecting (no banner)
  final String? error;

  SignalRConnectionState({
    this.isConnected = false,
    this.isReconnecting = false,
    this.isSilentReconnecting = false,
    this.error,
  });

  SignalRConnectionState copyWith({
    bool? isConnected,
    bool? isReconnecting,
    bool? isSilentReconnecting,
    String? error,
  }) {
    return SignalRConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      isSilentReconnecting: isSilentReconnecting ?? this.isSilentReconnecting,
      error: error,
    );
  }
}

class SignalRConnectionNotifier extends StateNotifier<SignalRConnectionState> {
  final SignalRService _signalRService;
  final dynamic _authRepository;
  final Ref _ref;
  
  // Stream controller for poll updates
  final _pollUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pollUpdates => _pollUpdateController.stream;

  SignalRConnectionNotifier(
    this._signalRService,
    this._authRepository,
    this._ref,
  ) : super(SignalRConnectionState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // #region agent log - Hypothesis C: Track SignalR initialization
      print('[SIGNALR_INIT] HYP_C_START: Starting SignalR initialization, timestamp: ${DateTime.now().toIso8601String()}');
      // #endregion
      final token = await _authRepository.getStoredToken();
      // #region agent log - Hypothesis C
      print('[SIGNALR_INIT] HYP_C_TOKEN: Token retrieved: ${token != null ? "yes (${token.substring(0, 20)}...)" : "no"}');
      // #endregion
      
      if (token != null) {
        // #region agent log - Hypothesis C
        final connectStart = DateTime.now();
        // #endregion
        await _signalRService.connect(token);
        // #region agent log - Hypothesis C
        final connectDuration = DateTime.now().difference(connectStart).inMilliseconds;
        print('[SIGNALR_INIT] HYP_C_CONNECTED: Connected in ${connectDuration}ms');
        // #endregion
        
        // Setup connection state callback to keep provider state in sync
        _signalRService.setOnConnectionStateChanged((isConnected) {
          print('[SignalR] Connection state changed: $isConnected');
          state = state.copyWith(isConnected: isConnected);
          
          // Update outbox sync service connection state
          try {
            final outboxSyncService = _ref.read(outboxSyncServiceProvider);
            outboxSyncService.setConnected(isConnected);
          } catch (e) {
            print('[SignalR] Error updating outbox sync connection state: $e');
          }
        });
        
        // Setup reconnected callback for status sync AND outbox sync
        _signalRService.setOnReconnectedCallback(() async {
          print('[SignalR] Reconnected callback triggered - syncing pending updates');
          
          // CRITICAL: Re-join all chats after reconnection
          await _joinAllUserChats();
          
          // Request incremental sync via SignalR to get missed messages/statuses
          try {
            await _signalRService.requestIncrementalSync();
            print('[SignalR] Incremental sync requested after reconnect');
          } catch (e) {
            print('[SignalR] Error requesting incremental sync: $e');
          }
          
          // Sync pending outbox messages (for messages we sent while offline)
          try {
            final outboxSyncService = _ref.read(outboxSyncServiceProvider);
            outboxSyncService.setConnected(true);
            await outboxSyncService.syncPendingMessages();
            print('[SignalR] Pending outbox messages synced after reconnect');
          } catch (e) {
            print('[SignalR] Error syncing outbox after reconnect: $e');
          }
        });
        
        _setupListeners();
        
        // Initialize outbox sync service
        try {
          final outboxSyncService = _ref.read(outboxSyncServiceProvider);
          outboxSyncService.setConnected(true);
          outboxSyncService.startPeriodicSync();
          print('[SignalR] Outbox sync service started');
        } catch (e) {
          print('[SignalR] Error starting outbox sync service: $e');
        }
        
        // CRITICAL: Auto-join all user's chats to receive status updates
        // This ensures the sender sees when their messages are read
        await _joinAllUserChats();
        
        state = state.copyWith(isConnected: true);
        print('[SignalR] Provider initialized and listeners setup');
      }
    } catch (e) {
      // #region agent log - Hypothesis C
      print('[SIGNALR_INIT] HYP_C_ERROR: Failed to initialize: $e');
      // #endregion
      print('[SignalR] Failed to initialize: $e');
      state = state.copyWith(error: e.toString(), isConnected: false);
    }
  }
  
  /// Auto-join all user's chats so we receive status updates for all messages
  /// This is critical for seeing when your messages are read by recipients
  Future<void> _joinAllUserChats() async {
    try {
      // CRITICAL: Force refresh to ensure we have the latest chats from server
      // This prevents missing status updates for newly created chats
      await _ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      
      final chats = _ref.read(chatsProvider).chats;
      print('[SignalR] Auto-joining ${chats.length} chats');
      
      for (final chat in chats) {
        try {
          await _signalRService.joinChat(chat.id);
        } catch (e) {
          print('[SignalR] Failed to auto-join chat ${chat.id}: $e');
        }
      }
      
      print('[SignalR] Auto-joined all ${chats.length} chats');
    } catch (e) {
      print('[SignalR] Error auto-joining chats: $e');
    }
  }
  
  void _setupListeners() {
    print('[SignalR] Setting up event listeners');
    
    // Setup message listener
        _signalRService.onReceiveMessage((message) async {
          print('[MSG_RECV] Message received via SignalR: ${message.id} for chat ${message.chatId}');
          
          // Check if this message is from us (ignore delivery confirmation for our own messages)
          final profileState = _ref.read(profileProvider);
          final currentUserId = profileState.profile?.id;
          final isFromMe = currentUserId != null && message.senderId == currentUserId;
          
          // Add message to appropriate chat provider first
          try {
            // Try to add message to the provider
            // If the provider doesn't exist (chat not open), it will be loaded when user opens the chat
            // addMessage() will ignore duplicate if message was already added locally
            await _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
            print('[MSG_RECV] Message added to provider for chat ${message.chatId}');
          } catch (e) {
            // Provider might not be initialized yet - that's OK, message will be loaded from API when chat opens
            print('[MSG_RECV] Message provider not initialized for chat ${message.chatId}: $e');
          }
          
          // Send delivery confirmation to backend (only for messages from others)
          if (!isFromMe) {
            try {
              _signalRService.markMessageAsDelivered(message.id, message.chatId);
              print('[MSG_RECV] Delivery confirmation sent for message: ${message.id}');
              
              // Update local message status to delivered immediately
              try {
                _ref.read(messagesProvider(message.chatId).notifier)
                    .updateMessageStatus(message.id, MessageStatus.delivered);
              } catch (e) {
                print('[MSG_RECV] Failed to update local status to delivered: $e');
              }
            } catch (e) {
              print('[MSG_RECV] Failed to send delivery confirmation: $e');
              // Retry after a delay
              Future.delayed(const Duration(seconds: 2), () {
                try {
                  _signalRService.markMessageAsDelivered(message.id, message.chatId);
                  print('[MSG_RECV] Delivery confirmation sent (retry): ${message.id}');
                } catch (retryError) {
                  print('[MSG_RECV] Delivery confirmation retry failed: $retryError');
                }
              });
            }
          } else {
            print('[MSG_RECV] Skipping delivery confirmation for own message: ${message.id}');
          }
          
          // Update chat preview with last message
          try {
            // Check if message is from current user
            final profileState = _ref.read(profileProvider);
            final currentUserId = profileState.profile?.id;
            final isFromMe = currentUserId != null && message.senderId == currentUserId;
            
            // Increment unread count only if message is from someone else
            _ref.read(chatsProvider.notifier).updateChatLastMessage(
              message.chatId, 
              message, 
              incrementUnread: !isFromMe,
            );
            print('[SignalR] Chat preview updated for chat ${message.chatId}, isFromMe: $isFromMe');
          } catch (e) {
            print('[SignalR] Failed to update chat preview: $e');
          }
          
          // Show notification
          try {
            final chatsState = _ref.read(chatsProvider);
            
            // Safely find chat, handle case when chats list is empty
            if (chatsState.chats.isEmpty) {
              print('[SignalR] Chats list is empty, skipping notification');
              return;
            }
            
            final chat = chatsState.chats.firstWhere(
              (c) => c.id == message.chatId,
              orElse: () {
                // Return a dummy chat or first chat if available
                return chatsState.chats.first;
              },
            );
            
            final notificationService = _ref.read(notificationServiceProvider);
            notificationService.showMessageNotification(message, chat.title);
          } catch (e) {
            print('[SignalR] Failed to show notification: $e');
          }
        });

        // Setup message status update listener
        _signalRService.onMessageStatusUpdated((messageId, status, chatId) {
          print('[STATUS_SYNC] Received MessageStatusUpdated - MessageId: $messageId, Status: $status, ChatId: $chatId');
          
          // ALWAYS cache the status update in global cache first
          try {
            _ref.read(pendingStatusUpdatesProvider.notifier).cacheStatusUpdate(messageId, status);
          } catch (e) {
            print('[STATUS_SYNC] Failed to cache status update: $e');
          }
          
          // Update message status - use chatId if provided for targeted update
          try {
            bool updated = false;
            
            if (chatId != null) {
              // Targeted update - only update the specific chat
              try {
                _ref.read(messagesProvider(chatId).notifier).updateMessageStatus(messageId, status);
                updated = true;
                print('[STATUS_SYNC] Updated status in chat $chatId');
              } catch (e) {
                print('[STATUS_SYNC] Provider not active for chat $chatId, status cached');
              }
            } else {
              // Fallback: try all chats (legacy support)
              final chatsState = _ref.read(chatsProvider);
              for (final chat in chatsState.chats) {
                try {
                  _ref.read(messagesProvider(chat.id).notifier).updateMessageStatus(messageId, status);
                  updated = true;
                  if (chatId == null) chatId = chat.id;
                } catch (e) {
                  // Provider not active
                }
              }
            }
            
            if (updated) {
              _ref.read(pendingStatusUpdatesProvider.notifier).consumeStatusUpdate(messageId);
            }
            
            // Clear unread count for this chat if message was marked as read/played
            if ((status == MessageStatus.read || status == MessageStatus.played) && chatId != null) {
              try {
                _ref.read(chatsProvider.notifier).clearUnreadCount(chatId);
                print('[STATUS_SYNC] Cleared unread count for chat $chatId');
              } catch (e) {
                print('[STATUS_SYNC] Failed to clear unread count: $e');
              }
            }
          } catch (e) {
            print('[STATUS_SYNC] Failed to update message status: $e');
          }
        });

        // Setup batch message status update listener (for efficiency when marking multiple messages)
        _signalRService.onBatchMessageStatusUpdated((messageIds, status) {
          print('[SignalR] Batch message status updated: ${messageIds.length} messages -> $status');
          
          // Cache all updates first
          for (final messageId in messageIds) {
            try {
              _ref.read(pendingStatusUpdatesProvider.notifier).cacheStatusUpdate(messageId, status);
            } catch (e) {
              print('[SignalR] Failed to cache batch status update for $messageId: $e');
            }
          }
          
          // Try to apply to all active providers
          try {
            final chatsState = _ref.read(chatsProvider);
            
            for (final chat in chatsState.chats) {
              try {
                for (final messageId in messageIds) {
                  _ref.read(messagesProvider(chat.id).notifier).updateMessageStatus(messageId, status);
                }
              } catch (e) {
                // Provider not active - status is cached
              }
            }
            
            // Consume cached updates that were applied
            for (final messageId in messageIds) {
              _ref.read(pendingStatusUpdatesProvider.notifier).consumeStatusUpdate(messageId);
            }
          } catch (e) {
            print('[SignalR] Failed to apply batch status updates: $e');
          }
        });

        // Setup typing indicator listener
        // activityType: 0 = typing text, 1 = recording audio
        _signalRService.onUserTyping((chatId, userId, userName, isTyping, activityType) {
          print('[SignalR] User activity indicator: $userName ($userId) in chat $chatId - active: $isTyping, type: $activityType');
          
          try {
            // Update typing state only for the specific chat
            _ref.read(typingProvider.notifier).setUserTyping(
              chatId, 
              userId, 
              userName, 
              isTyping,
              activityType: activityType, // 0 = typing, 1 = recording audio
            );
          } catch (e) {
            print('[SignalR] Failed to process typing indicator: $e');
          }
        });
        
        // Setup user status changed listener (online/offline)
        _signalRService.onUserStatusChanged((userId, isOnline, lastSeenAt) {
          print('[SignalR] User status changed: $userId - isOnline: $isOnline, lastSeen: $lastSeenAt');
          
          try {
            _ref.read(onlineUsersProvider.notifier).setUserOnline(userId, isOnline);
            
            if (lastSeenAt != null) {
              _ref.read(lastSeenMapProvider.notifier).setLastSeen(userId, lastSeenAt);
            }
          } catch (e) {
            print('[SignalR] Failed to update user status: $e');
          }
        });
        
        // Setup poll updated listener
        _signalRService.onPollUpdated((messageId, pollData) {
          print('[SignalR] Poll updated: messageId=$messageId');
          
          try {
            // Broadcast to stream for any listeners
            _pollUpdateController.add({'messageId': messageId, 'poll': pollData});
            
            // Update poll in all active message providers
            final chatsState = _ref.read(chatsProvider);
            for (final chat in chatsState.chats) {
              try {
                _ref.read(messagesProvider(chat.id).notifier)
                    .handlePollUpdated(messageId, pollData);
              } catch (e) {
                // Provider might not be initialized, ignore
              }
            }
          } catch (e) {
            print('[SignalR] Failed to process poll update: $e');
          }
        });

        // Setup new chat created listener
        _signalRService.onNewChatCreated(() {
          print('[SignalR] New chat created event received');
          
          // Refresh chats list when new chat is created
          try {
            _ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
            print('[SignalR] Chats list refreshed');
          } catch (e) {
            print('[SignalR] Failed to refresh chats on new chat created: $e');
          }
          
          // Refresh contacts mapping to include new chat participant names
          try {
            _ref.read(contactsNamesProvider.notifier).loadContactsMapping();
            print('[SignalR] Contacts mapping refreshed');
          } catch (e) {
            print('[SignalR] Failed to refresh contacts mapping: $e');
          }
        });

        // Setup message deleted listener
        _signalRService.onMessageDeleted((data) {
          try {
            final messageId = data['messageId'] as String;
            final chatId = data['chatId'] as String;
            
            // Remove message from the chat provider
            try {
              _ref.read(messagesProvider(chatId).notifier).removeMessage(messageId);
            } catch (e) {
              // Provider not active - that's OK
            }
            
            // Refresh chats list to update last message preview
            _ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
          } catch (e) {
            print('[SignalR] Failed to handle MessageDeleted: $e');
          }
        });
        
        // Setup message edited listener
        _signalRService.onMessageEdited((data) {
          try {
            final messageId = data['id'] as String;
            final chatId = data['chatId'] as String;
            final newContent = data['content'] as String?;
            final editedAtStr = data['editedAt'] as String?;
            final editedAt = editedAtStr != null ? DateTime.parse(editedAtStr) : DateTime.now();
            
            // Update message in the chat provider
            try {
              if (newContent != null) {
                _ref.read(messagesProvider(chatId).notifier).handleMessageEdited(
                  messageId, 
                  newContent, 
                  editedAt,
                );
              }
            } catch (e) {
              // Provider not active - that's OK
            }
          } catch (e) {
            print('[SignalR] Failed to handle MessageEdited: $e');
          }
        });

        // Setup chat deleted listener
        _signalRService.onChatDeleted((data) {
          try {
            final chatId = data['chatId'] as String;
            
            // Remove chat from the chats list
            _ref.read(chatsProvider.notifier).removeChat(chatId);
          } catch (e) {
            print('[SignalR] Failed to handle ChatDeleted: $e');
          }
        });
  }

  Future<void> reconnect() async {
    print('[SignalR] Manual reconnect requested');
    try {
      // Use the service's force reconnect method which handles retries
      await _signalRService.forceReconnectFromLifecycle();
      
      // Update state based on actual connection status
      final isConnected = _signalRService.isConnected;
      state = state.copyWith(isConnected: isConnected);
      
      if (isConnected) {
        print('[SignalR] Reconnected successfully');
      } else {
        print('[SignalR] Reconnect in progress...');
      }
    } catch (e) {
      print('[SignalR] Reconnect failed: $e');
      state = state.copyWith(error: e.toString(), isConnected: false);
    }
  }
  
  /// Set visible reconnecting state (shows banner to user)
  void setReconnecting(bool value) {
    print('[SignalR] Setting reconnecting state: $value');
    state = state.copyWith(
      isReconnecting: value,
      isSilentReconnecting: false, // Clear silent reconnecting if setting visible reconnecting
    );
  }
  
  /// Perform silent reconnect without showing banner
  Future<void> silentReconnect() async {
    if (state.isConnected) {
      print('[SignalR] Already connected, skipping silent reconnect');
      return;
    }
    
    print('[SignalR] Starting silent reconnect');
    state = state.copyWith(
      isSilentReconnecting: true,
      isReconnecting: false, // Clear visible reconnecting
    );
    
    try {
      await _signalRService.forceReconnectFromLifecycle();
      
      final isConnected = _signalRService.isConnected;
      state = state.copyWith(
        isConnected: isConnected,
        isSilentReconnecting: false,
      );
      
      if (isConnected) {
        print('[SignalR] Silent reconnect successful');
      }
    } catch (e) {
      print('[SignalR] Silent reconnect failed: $e');
      state = state.copyWith(
        error: e.toString(),
        isConnected: false,
        isSilentReconnecting: false,
      );
    }
  }

  Future<void> disconnect() async {
    // Stop outbox sync service
    try {
      final outboxSyncService = _ref.read(outboxSyncServiceProvider);
      outboxSyncService.setConnected(false);
      outboxSyncService.stopPeriodicSync();
    } catch (e) {
      print('[SignalR] Error stopping outbox sync service: $e');
    }
    
    await _signalRService.disconnect();
    state = SignalRConnectionState();
  }
}


