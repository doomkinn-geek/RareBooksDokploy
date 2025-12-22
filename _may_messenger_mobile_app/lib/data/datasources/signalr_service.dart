import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';

class SignalRService {
  HubConnection? _hubConnection;
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
            // Connection timeout
            requestTimeout: 30000, // 30 seconds
          ),
        )
        // Exponential backoff: 0s, 2s, 5s, 10s, 30s, 60s
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000, 60000])
        .build();

    // Обработчик разрыва соединения
    _hubConnection?.onclose(({error}) {
      print('[SignalR] Connection closed. Error: $error');
      _isReconnecting = false;
      
      // Automatic reconnect will be handled by withAutomaticReconnect
      // But if that fails completely, try manual reconnect
      if (_currentToken != null) {
        print('[SignalR] Scheduling manual reconnect attempt...');
        Future.delayed(const Duration(seconds: 5), () {
          if (_hubConnection?.state != HubConnectionState.Connected && !_isReconnecting) {
            _attemptReconnect();
          }
        });
      }
    });
    
    // Обработчик начала переподключения
    _hubConnection?.onreconnecting(({error}) {
      print('[SignalR] Reconnecting... Error: $error');
      _isReconnecting = true;
    });
    
    // Обработчик успешного переподключения
    _hubConnection?.onreconnected(({connectionId}) {
      print('[SignalR] Reconnected successfully! Connection ID: $connectionId');
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
    if (_currentToken == null || _isReconnecting) {
      print('[SignalR] Reconnect skipped - already reconnecting or no token');
      return;
    }
    
    _isReconnecting = true;
    print('[SignalR] Manual reconnect attempt started');
    
    try {
      // Stop existing connection
      try {
        await _hubConnection?.stop();
      } catch (e) {
        print('[SignalR] Error stopping connection: $e');
      }
      
      // Wait a bit before reconnecting
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if still disconnected
      if (_hubConnection?.state != HubConnectionState.Connected) {
        print('[SignalR] Attempting to establish new connection...');
        await connect(_currentToken!);
        print('[SignalR] Manual reconnect successful');
      }
    } catch (e) {
      print('[SignalR] Manual reconnect failed: $e');
      _isReconnecting = false;
      
      // Schedule another attempt with exponential backoff
      print('[SignalR] Scheduling retry in 10 seconds...');
      await Future.delayed(const Duration(seconds: 10));
      
      // Only retry if still disconnected
      if (_hubConnection?.state != HubConnectionState.Connected) {
        _attemptReconnect();
      }
    } finally {
      if (_hubConnection?.state == HubConnectionState.Connected) {
        _isReconnecting = false;
      }
    }
  }
  
  HubConnectionState? get connectionState => _hubConnection?.state;

  void onReceiveMessage(Function(Message) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('ReceiveMessage');
    
    _hubConnection?.on('ReceiveMessage', (arguments) async {
      if (arguments != null && arguments.isNotEmpty) {
        final messageJson = arguments[0] as Map<String, dynamic>;
        final message = Message.fromJson(messageJson);
        callback(message);
        
        // Automatically send ACK
        try {
          await ackMessageReceived(message.id);
        } catch (e) {
          print('[SignalR] Failed to auto-send ACK: $e');
        }
      }
    });
  }

  void onMessageStatusUpdated(Function(String messageId, MessageStatus status) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('MessageStatusUpdated');
    
    _hubConnection?.on('MessageStatusUpdated', (arguments) async {
      if (arguments != null && arguments.length >= 2) {
        final messageId = arguments[0] as String;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        callback(messageId, status);
        
        // Automatically send ACK
        try {
          await ackStatusUpdate(messageId, statusIndex);
        } catch (e) {
          print('[SignalR] Failed to auto-send status ACK: $e');
        }
      }
    });
  }
  
  /// Register callback for user status changes (online/offline)
  void onUserStatusChanged(Function(String userId, bool isOnline, DateTime? lastSeenAt) callback) {
    // Unsubscribe from previous handler
    _hubConnection?.off('UserStatusChanged');
    
    _hubConnection?.on('UserStatusChanged', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        final userId = arguments[0] as String;
        final isOnline = arguments[1] as bool;
        DateTime? lastSeenAt;
        
        if (arguments.length >= 3 && arguments[2] != null) {
          try {
            lastSeenAt = DateTime.parse(arguments[2] as String);
          } catch (e) {
            print('[SignalR] Failed to parse lastSeenAt: $e');
          }
        }
        
        print('[SignalR] User status changed: userId=$userId, isOnline=$isOnline, lastSeenAt=$lastSeenAt');
        callback(userId, isOnline, lastSeenAt);
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

  /// Send acknowledgment that message was received via SignalR
  Future<void> ackMessageReceived(String messageId) async {
    if (!isConnected) {
      print('[SignalR] Cannot send ACK - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('AckMessageReceived', args: [messageId]);
      print('[SignalR] Sent ACK for message: $messageId');
    } catch (e) {
      print('[SignalR] Failed to send message ACK: $e');
    }
  }

  /// Send acknowledgment that status update was received via SignalR
  Future<void> ackStatusUpdate(String messageId, int status) async {
    if (!isConnected) {
      print('[SignalR] Cannot send status ACK - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('AckStatusUpdate', args: [messageId, status]);
      print('[SignalR] Sent ACK for status update: $messageId -> $status');
    } catch (e) {
      print('[SignalR] Failed to send status ACK: $e');
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
