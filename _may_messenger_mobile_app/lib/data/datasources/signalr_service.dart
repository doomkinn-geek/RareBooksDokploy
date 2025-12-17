import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final _logger = LoggerService();
  String? _currentToken;
  bool _isReconnecting = false;

  Future<void> connect(String token) async {
    _currentToken = token;
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          ApiConstants.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();

    // Обработчик разрыва соединения
    _hubConnection?.onclose(({error}) {
      print('[SignalR] Connection closed. Error: $error');
      if (!_isReconnecting && _currentToken != null) {
        print('[SignalR] Attempting to reconnect...');
        _attemptReconnect();
      }
    });
    
    // Обработчик начала переподключения
    _hubConnection?.onreconnecting(({error}) {
      print('[SignalR] Reconnecting... Error: $error');
      _isReconnecting = true;
    });
    
    // Обработчик успешного переподключения
    _hubConnection?.onreconnected(({connectionId}) {
      print('[SignalR] Reconnected! Connection ID: $connectionId');
      _isReconnecting = false;
    });

    try {
      await _hubConnection?.start();
      print('[SignalR] Connected successfully');
    } catch (e) {
      print('[SignalR] Failed to connect: $e');
      rethrow;
    }
  }
  
  Future<void> _attemptReconnect() async {
    if (_currentToken == null || _isReconnecting) return;
    
    _isReconnecting = true;
    
    try {
      await Future.delayed(const Duration(seconds: 2));
      
      if (_hubConnection?.state != HubConnectionState.Connected) {
        print('[SignalR] Reconnecting...');
        await _hubConnection?.stop();
        await connect(_currentToken!);
      }
    } catch (e) {
      print('[SignalR] Reconnect failed: $e');
      // Попробуем еще раз через 5 секунд
      await Future.delayed(const Duration(seconds: 5));
      _isReconnecting = false;
      _attemptReconnect();
    } finally {
      _isReconnecting = false;
    }
  }
  
  HubConnectionState? get connectionState => _hubConnection?.state;

  void onReceiveMessage(Function(Message) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('ReceiveMessage');
    
    _hubConnection?.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageJson = arguments[0] as Map<String, dynamic>;
        final message = Message.fromJson(messageJson);
        callback(message);
      }
    });
  }

  void onMessageStatusUpdated(Function(String messageId, MessageStatus status) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('MessageStatusUpdated');
    
    _hubConnection?.on('MessageStatusUpdated', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        final messageId = arguments[0] as String;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        callback(messageId, status);
      }
    });
  }

  Future<void> markMessageAsDelivered(String messageId, String chatId) async {
    if (!isConnected) {
      print('[SignalR] Cannot mark as delivered - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('MessageDelivered', args: [messageId, chatId]);
      print('[SignalR] Message marked as delivered: $messageId');
    } catch (e) {
      print('[SignalR] Failed to send delivery confirmation: $e');
    }
  }

  Future<void> markMessageAsRead(String messageId, String chatId) async {
    if (!isConnected) {
      print('[SignalR] Cannot mark as read - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('MessageRead', args: [messageId, chatId]);
      print('[SignalR] Message marked as read: $messageId');
    } catch (e) {
      print('[SignalR] Failed to mark as read: $e');
    }
  }

  void onUserTyping(Function(String userId, String userName, bool isTyping) callback) {
    _hubConnection?.off('UserTyping');
    
    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        final userId = arguments[0] as String;
        final userName = arguments[1] as String;
        final isTyping = arguments[2] as bool;
        callback(userId, userName, isTyping);
      }
    });
  }

  void onNewChatCreated(Function() callback) {
    _hubConnection?.off('NewChatCreated');
    
    _hubConnection?.on('NewChatCreated', (arguments) {
      // When a new chat is created, just trigger refresh
      callback();
    });
  }

  Future<void> joinChat(String chatId) async {
    if (!isConnected) {
      print('[SignalR] Cannot join chat - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('JoinChat', args: [chatId]);
      print('[SignalR] Joined chat: $chatId');
    } catch (e) {
      print('[SignalR] Failed to join chat: $e');
    }
  }

  Future<void> leaveChat(String chatId) async {
    if (!isConnected) {
      print('[SignalR] Cannot leave chat - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('LeaveChat', args: [chatId]);
      print('[SignalR] Left chat: $chatId');
    } catch (e) {
      print('[SignalR] Failed to leave chat: $e');
    }
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

  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    if (!isConnected) {
      return; // Не логируем - это не критично
    }
    
    try {
      await _hubConnection?.invoke('TypingIndicator', args: [chatId, isTyping]);
    } catch (e) {
      // Игнорируем ошибки typing indicator
    }
  }

  void onMessageDeleted(Function(Map<String, dynamic>) callback) {
    _hubConnection?.off('MessageDeleted');
    
    _hubConnection?.on('MessageDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<Object?, Object?>;
        final convertedData = <String, dynamic>{};
        data.forEach((key, value) {
          if (key != null) {
            convertedData[key.toString()] = value;
          }
        });
        callback(convertedData);
      }
    });
  }

  void onChatDeleted(Function(Map<String, dynamic>) callback) {
    _hubConnection?.off('ChatDeleted');
    
    _hubConnection?.on('ChatDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<Object?, Object?>;
        final convertedData = <String, dynamic>{};
        data.forEach((key, value) {
          if (key != null) {
            convertedData[key.toString()] = value;
          }
        });
        callback(convertedData);
      }
    });
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
  }

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
}
