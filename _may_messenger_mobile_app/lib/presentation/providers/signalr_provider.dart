import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_service.dart';
import '../../core/services/logger_service.dart';
import 'auth_provider.dart';
import 'messages_provider.dart';
import 'chats_provider.dart';
import 'contacts_names_provider.dart';
import 'profile_provider.dart';
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
  final String? error;

  SignalRConnectionState({
    this.isConnected = false,
    this.error,
  });

  SignalRConnectionState copyWith({
    bool? isConnected,
    String? error,
  }) {
    return SignalRConnectionState(
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }
}

class SignalRConnectionNotifier extends StateNotifier<SignalRConnectionState> {
  final SignalRService _signalRService;
  final dynamic _authRepository;
  final Ref _ref;
  final _logger = LoggerService();

  SignalRConnectionNotifier(
    this._signalRService,
    this._authRepository,
    this._ref,
  ) : super(SignalRConnectionState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final token = await _authRepository.getStoredToken();
      
      if (token != null) {
        await _signalRService.connect(token);
        _setupListeners();
        
        state = state.copyWith(isConnected: true);
        print('[SignalR] Provider initialized and listeners setup');
      }
    } catch (e) {
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
          print('[SignalR] Message status updated: $messageId -> $status');
          
          // Update message status in all providers
          try {
            // Try to update in all active chat providers
            // This will update the UI for the sender
            final chatsState = _ref.read(chatsProvider);
            int updatedCount = 0;
            
            for (final chat in chatsState.chats) {
              try {
                _ref.read(messagesProvider(chat.id).notifier).updateMessageStatus(messageId, status);
                updatedCount++;
              } catch (e) {
                // Provider not active - that's OK
              }
            }
            
            if (updatedCount > 0) {
              print('[SignalR] Message status updated in $updatedCount chat(s)');
            }
          } catch (e) {
            print('[SignalR] Failed to update message status: $e');
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
      final token = await _authRepository.getStoredToken();
      if (token != null) {
        await _signalRService.connect(token);
        _setupListeners();
        state = state.copyWith(isConnected: true);
        print('[SignalR] Reconnected successfully');
      }
    } catch (e) {
      print('[SignalR] Reconnect failed: $e');
      state = state.copyWith(error: e.toString(), isConnected: false);
    }
  }

  Future<void> disconnect() async {
    await _signalRService.disconnect();
    state = SignalRConnectionState();
  }
}


