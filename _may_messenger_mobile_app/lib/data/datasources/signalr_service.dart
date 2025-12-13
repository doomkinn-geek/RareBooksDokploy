import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final _logger = LoggerService();

  Future<void> connect(String token) async {
    // #region agent log
    await _logger.debug('signalr_service.connect.entry', '[H1,H2] Connecting to SignalR', {'hubUrl': ApiConstants.hubUrl});
    // #endregion
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          ApiConstants.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    // #region agent log
    await _logger.debug('signalr_service.connect.starting', '[H1,H2] Calling hubConnection.start()', {});
    // #endregion

    await _hubConnection?.start();
    
    // #region agent log
    await _logger.debug('signalr_service.connect.done', '[H1,H2] SignalR connected', {'state': '${_hubConnection?.state}', 'connectionId': '${_hubConnection?.connectionId}'});
    // #endregion
  }

  void onReceiveMessage(Function(Message) callback) {
    // #region agent log
    _logger.debug('signalr_service.onReceiveMessage.register', '[H1,H2] Registering ReceiveMessage handler', {'connectionState': '${_hubConnection?.state}'});
    // #endregion
    
    _hubConnection?.on('ReceiveMessage', (arguments) {
      // #region agent log
      _logger.debug('signalr_service.onReceiveMessage.fired', '[H1,H2-CRITICAL] ReceiveMessage event FIRED from backend', {'hasArgs': '${arguments != null && arguments.isNotEmpty}', 'argCount': '${arguments?.length ?? 0}', 'connectionState': '${_hubConnection?.state}'});
      // #endregion
      
      if (arguments != null && arguments.isNotEmpty) {
        final messageJson = arguments[0] as Map<String, dynamic>;
        
        // #region agent log
        _logger.debug('signalr_service.onReceiveMessage.parsing', '[H1,H2] Parsing message JSON', {'jsonKeys': '${messageJson.keys.join(", ")}'});
        // #endregion
        
        final message = Message.fromJson(messageJson);
        
        // #region agent log
        _logger.debug('signalr_service.onReceiveMessage.parsed', '[H1,H2] Message parsed successfully', {'messageId': message.id, 'chatId': message.chatId, 'senderId': message.senderId, 'content': message.content ?? 'audio'});
        // #endregion
        
        callback(message);
        
        // #region agent log
        _logger.debug('signalr_service.onReceiveMessage.callbackDone', '[H1,H2] Callback executed', {'messageId': message.id});
        // #endregion
      }
    });
  }

  void onMessageStatusUpdated(Function(String messageId, MessageStatus status) callback) {
    _hubConnection?.on('MessageStatusUpdated', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        final messageId = arguments[0] as String;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        callback(messageId, status);
      }
    });
  }

  void onUserTyping(Function(String userId, String userName, bool isTyping) callback) {
    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        final userId = arguments[0] as String;
        final userName = arguments[1] as String;
        final isTyping = arguments[2] as bool;
        callback(userId, userName, isTyping);
      }
    });
  }

  Future<void> joinChat(String chatId) async {
    // #region agent log
    await _logger.debug('signalr_service.joinChat.entry', '[H2] JoinChat invoked', {'chatId': chatId, 'connectionState': '${_hubConnection?.state}', 'isConnected': '$isConnected'});
    // #endregion
    
    await _hubConnection?.invoke('JoinChat', args: [chatId]);
    
    // #region agent log
    await _logger.debug('signalr_service.joinChat.done', '[H2] JoinChat completed', {'chatId': chatId});
    // #endregion
  }

  Future<void> leaveChat(String chatId) async {
    await _hubConnection?.invoke('LeaveChat', args: [chatId]);
  }

  Future<void> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
  }) async {
    await _hubConnection?.invoke('SendMessage', args: [
      {
        'chatId': chatId,
        'type': type.index,
        'content': content,
      }
    ]);
  }

  Future<void> markMessageAsRead(String messageId, String chatId) async {
    await _hubConnection?.invoke('MessageRead', args: [messageId, chatId]);
  }

  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    await _hubConnection?.invoke('TypingIndicator', args: [chatId, isTyping]);
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
  }

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
}


