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
      // #region agent log
      await _logger.debug('signalr_provider._initialize.entry', '[H5] Initializing SignalR connection', {});
      // #endregion
      
      final token = await _authRepository.getStoredToken();
      
      // #region agent log
      await _logger.debug('signalr_provider._initialize.token', '[H5] Token retrieved', {'hasToken': '${token != null}'});
      // #endregion
      
      if (token != null) {
        await _signalRService.connect(token);
        
        // #region agent log
        await _logger.debug('signalr_provider._initialize.connected', '[H5] SignalR connected, setting up handlers', {});
        // #endregion

        // Setup message listener
        _signalRService.onReceiveMessage((message) {
          // #region agent log
          _logger.debug('signalr_provider.onReceiveMessage.entry', '[H1] Message received via SignalR', {'messageId': message.id, 'chatId': message.chatId, 'senderId': message.senderId, 'content': message.content ?? 'audio'});
          // #endregion
          
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
            _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
            
            // #region agent log
            _logger.debug('signalr_provider.onReceiveMessage.added', '[H1] Message added to provider', {'messageId': message.id, 'chatId': message.chatId});
            // #endregion
          } catch (e) {
            // #region agent log
            _logger.error('signalr_provider.onReceiveMessage.providerError', '[H1] Error accessing messages provider', {'error': e.toString(), 'messageId': message.id, 'chatId': message.chatId});
            // #endregion
            // Provider might not be initialized yet - that's OK, message will be loaded from API when chat opens
          }
          
          // Show notification and update chat list regardless of provider state
          try {
            final chatsState = _ref.read(chatsProvider);
            
            // Safely find chat, handle case when chats list is empty
            if (chatsState.chats.isEmpty) {
              // #region agent log
              _logger.debug('signalr_provider.onReceiveMessage.noChats', '[H1] Chats list is empty, skipping notification', {'messageId': message.id});
              // #endregion
              return;
            }
            
            final chat = chatsState.chats.firstWhere(
              (c) => c.id == message.chatId,
              orElse: () {
                // #region agent log
                _logger.debug('signalr_provider.onReceiveMessage.chatNotFound', '[H1] Chat not found in list, skipping notification', {'messageId': message.id, 'chatId': message.chatId});
                // #endregion
                // Return a dummy chat or first chat if available
                return chatsState.chats.first;
              },
            );
            
            final notificationService = _ref.read(notificationServiceProvider);
            notificationService.showMessageNotification(message, chat.title);
            
            // #region agent log
            _logger.debug('signalr_provider.onReceiveMessage.notificationShown', '[H1] Notification shown', {'messageId': message.id});
            // #endregion
          } catch (e) {
            // #region agent log
            _logger.error('signalr_provider.onReceiveMessage.notificationError', '[H1] Error showing notification', {'error': e.toString(), 'messageId': message.id});
            // #endregion
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

        state = state.copyWith(isConnected: true);
        
        // #region agent log
        await _logger.debug('signalr_provider._initialize.complete', '[H5] SignalR initialization complete', {});
        // #endregion
      }
    } catch (e) {
      // #region agent log
      await _logger.error('signalr_provider._initialize.error', '[H5] SignalR init failed', {'error': e.toString()});
      // #endregion
      
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


