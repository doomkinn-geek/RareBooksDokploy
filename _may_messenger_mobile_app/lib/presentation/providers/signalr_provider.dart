import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/signalr_service.dart';
import '../../core/services/logger_service.dart';
import 'auth_provider.dart';
import 'messages_provider.dart';
import 'chats_provider.dart';
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

        // Setup message listener
        _signalRService.onReceiveMessage((message) {
          // Send delivery confirmation to backend
          try {
            _signalRService.markMessageAsDelivered(message.id, message.chatId);
          } catch (e) {
            print('Failed to send delivery confirmation: $e');
          }
          
          // Add message to appropriate chat
          try {
            // Try to add message to the provider
            // If the provider doesn't exist (chat not open), it will be loaded when user opens the chat
            // addMessage() will ignore duplicate if message was already added locally
            _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
          } catch (e) {
            // Provider might not be initialized yet - that's OK, message will be loaded from API when chat opens
          }
          
          // Show notification and update chat list regardless of provider state
          try {
            final chatsState = _ref.read(chatsProvider);
            
            // Safely find chat, handle case when chats list is empty
            if (chatsState.chats.isEmpty) {
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
            // Notification error, ignore
          }
        });

        // Setup message status update listener
        _signalRService.onMessageStatusUpdated((messageId, status) {
          // Update message status in all providers
          try {
            // Try to update in all active chat providers
            // This will update the UI for the sender
            final chatsState = _ref.read(chatsProvider);
            for (final chat in chatsState.chats) {
              try {
                _ref.read(messagesProvider(chat.id).notifier).updateMessageStatus(messageId, status);
              } catch (e) {
                // Provider not active - that's OK
              }
            }
          } catch (e) {
            print('Failed to update message status: $e');
          }
        });

        // Setup new chat created listener
        _signalRService.onNewChatCreated(() {
          // Refresh chats list when new chat is created
          try {
            _ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
          } catch (e) {
            print('Failed to refresh chats on new chat created: $e');
          }
        });

        state = state.copyWith(isConnected: true);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reconnect() async {
    await _initialize();
  }

  Future<void> disconnect() async {
    await _signalRService.disconnect();
    state = SignalRConnectionState();
  }
}


