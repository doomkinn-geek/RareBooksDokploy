import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_service.dart';
import '../../data/models/message_model.dart';
import '../../core/services/logger_service.dart';
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
        
        // Setup reconnected callback for status sync
        _signalRService.setOnReconnectedCallback(() async {
          print('[SignalR] Reconnected callback triggered - syncing pending status updates');
          try {
            final statusSyncService = _ref.read(statusSyncServiceProvider);
            await statusSyncService.forceSync();
            print('[SignalR] Pending status updates synced after reconnect');
          } catch (e) {
            print('[SignalR] Error syncing status updates after reconnect: $e');
          }
        });
        
        _setupListeners();
        
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
  
  void _setupListeners() {
    print('[SignalR] Setting up event listeners');
    
    // Setup message listener
        _signalRService.onReceiveMessage((message) {
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
            _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
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
        _signalRService.onMessageStatusUpdated((messageId, status) {
          // #region agent log
          print('[SIGNALR_STATUS] HYP_SIGNALR: Received MessageStatusUpdated - MessageId: $messageId, Status: $status, Timestamp: ${DateTime.now().toIso8601String()}');
          // #endregion
          print('[SignalR] Message status updated: $messageId -> $status');
          
          // Update message status in all providers
          try {
            // Try to update in all active chat providers
            // This will update the UI for the sender
            final chatsState = _ref.read(chatsProvider);
            int updatedCount = 0;
            String? foundChatId;
            // #region agent log
            print('[SIGNALR_STATUS] HYP_SIGNALR: Total chats: ${chatsState.chats.length}');
            // #endregion
            
            for (final chat in chatsState.chats) {
              try {
                _ref.read(messagesProvider(chat.id).notifier).updateMessageStatus(messageId, status);
                updatedCount++;
                foundChatId = chat.id;
                // #region agent log
                print('[SIGNALR_STATUS] HYP_SIGNALR: Updated status in chat ${chat.id}');
                // #endregion
              } catch (e) {
                // Provider not active - that's OK
                // #region agent log
                print('[SIGNALR_STATUS] HYP_SIGNALR: Failed to update chat ${chat.id}: $e');
                // #endregion
              }
            }
            
            if (updatedCount > 0) {
              print('[SignalR] Message status updated in $updatedCount chat(s)');
            }
            
            // Update unread count if message was marked as read
            if (status == MessageStatus.read && foundChatId != null) {
              try {
                _ref.read(chatsProvider.notifier).updateUnreadCountOnStatusUpdate(
                  foundChatId, 
                  messageId, 
                  status
                );
                print('[SignalR] Updated unread count for chat preview after read status');
              } catch (e) {
                print('[SignalR] Failed to update unread count: $e');
              }
            }
          } catch (e) {
            print('[SignalR] Failed to update message status: $e');
          }
        });

        // Setup typing indicator listener
        _signalRService.onUserTyping((userId, userName, isTyping) {
          print('[SignalR] User typing indicator: $userName ($userId) - $isTyping');
          
          try {
            // Find which chat this user is typing in by checking all chats
            final chatsState = _ref.read(chatsProvider);
            for (final chat in chatsState.chats) {
              // Update typing state for this chat
              // The chatId context will be determined by the chat screen itself
              // For now, we'll let the typing provider handle it globally
              _ref.read(typingProvider.notifier).setUserTyping(
                chat.id, 
                userId, 
                userName, 
                isTyping
              );
            }
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
    await _signalRService.disconnect();
    state = SignalRConnectionState();
  }
}


