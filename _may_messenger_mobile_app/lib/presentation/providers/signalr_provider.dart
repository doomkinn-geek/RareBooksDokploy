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
          
          // Add message to appropriate chat
          try {
            _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
            
            // #region agent log
            _logger.debug('signalr_provider.onReceiveMessage.added', '[H1] Message added to provider', {'messageId': message.id});
            // #endregion
            
            // Show notification if user is not in the current chat
            final chatsState = _ref.read(chatsProvider);
            
            final chat = chatsState.chats.firstWhere(
              (c) => c.id == message.chatId,
              orElse: () => chatsState.chats.first,
            );
            
            final notificationService = _ref.read(notificationServiceProvider);
            notificationService.showMessageNotification(message, chat.title);
          } catch (e) {
            // #region agent log
            _logger.error('signalr_provider.onReceiveMessage.error', '[H1] Error handling message', {'error': e.toString(), 'messageId': message.id});
            // #endregion
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


