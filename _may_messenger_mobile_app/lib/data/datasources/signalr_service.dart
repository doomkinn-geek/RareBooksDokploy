import 'dart:async';
import 'dart:math';
import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';

class SignalRService {
  HubConnection? _hubConnection;
  String? _currentToken;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastSyncTimestamp;
  Timer? _heartbeatTimer;
  DateTime? _lastPongReceived;

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
      
      // Stop heartbeat timer
      _stopHeartbeatTimer();
      
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
    _hubConnection?.onreconnected(({connectionId}) async {
      print('[SignalR] Reconnected successfully! Connection ID: $connectionId');
      _isReconnecting = false;
      _reconnectAttempts = 0;
      
      // Restart heartbeat timer
      _startHeartbeatTimer();
      
      // Perform incremental sync after reconnection
      await _performIncrementalSync();
    });

    // Setup Pong handler before connecting
    _setupPongHandler();
    
    try {
      await _hubConnection?.start();
      print('[SignalR] Connected successfully');
      
      // Start heartbeat timer after successful connection
      _startHeartbeatTimer();
    } catch (e) {
      print('[SignalR] Failed to connect: $e');
      rethrow;
    }
  }
  
  /// Setup Pong handler to receive server heartbeat responses
  void _setupPongHandler() {
    _hubConnection?.off('Pong');
    _hubConnection?.on('Pong', (arguments) {
      _lastPongReceived = DateTime.now();
      print('[SignalR] Pong received');
    });
  }
  
  /// Start heartbeat timer - sends Heartbeat every 30 seconds
  void _startHeartbeatTimer() {
    _stopHeartbeatTimer(); // Stop any existing timer
    
    _lastPongReceived = DateTime.now();
    
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_hubConnection?.state == HubConnectionState.Connected) {
        try {
          print('[SignalR] Sending heartbeat...');
          await _hubConnection?.invoke('Heartbeat');
          
          // Check if we received Pong recently (within last 90 seconds)
          if (_lastPongReceived != null) {
            final timeSinceLastPong = DateTime.now().difference(_lastPongReceived!);
            if (timeSinceLastPong.inSeconds > 90) {
              print('[SignalR] No Pong received for ${timeSinceLastPong.inSeconds}s - forcing reconnect');
              timer.cancel();
              await _forceReconnect();
            }
          }
        } catch (e) {
          print('[SignalR] Heartbeat failed: $e');
          // Connection might be dead, trigger reconnect
          timer.cancel();
          await _forceReconnect();
        }
      } else {
        print('[SignalR] Not connected, stopping heartbeat timer');
        timer.cancel();
      }
    });
    
    print('[SignalR] Heartbeat timer started (30s interval)');
  }
  
  /// Stop heartbeat timer
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Force reconnect when heartbeat fails
  Future<void> _forceReconnect() async {
    print('[SignalR] Forcing reconnect due to heartbeat failure');
    _stopHeartbeatTimer();
    await _attemptReconnect();
  }
  
  Future<void> _attemptReconnect() async {
    if (_currentToken == null || _isReconnecting) {
      print('[SignalR] Reconnect skipped - already reconnecting or no token');
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    print('[SignalR] Manual reconnect attempt #$_reconnectAttempts started');
    
    try {
      // Stop existing connection
      try {
        await _hubConnection?.stop();
      } catch (e) {
        print('[SignalR] Error stopping connection: $e');
      }
      
      // Exponential backoff with jitter
      // Base delay: 2^attempts seconds, max 60 seconds
      // Jitter: random 0-2 seconds to prevent thundering herd
      final baseDelay = min(pow(2, _reconnectAttempts).toInt(), 60);
      final jitter = Random().nextInt(2000); // 0-2000ms
      final totalDelay = Duration(seconds: baseDelay, milliseconds: jitter);
      
      print('[SignalR] Waiting ${totalDelay.inSeconds}s before reconnect (with jitter)');
      await Future.delayed(totalDelay);
      
      // Check if still disconnected
      if (_hubConnection?.state != HubConnectionState.Connected) {
        print('[SignalR] Attempting to establish new connection...');
        await connect(_currentToken!);
        print('[SignalR] Manual reconnect successful');
        _reconnectAttempts = 0; // Reset on success
      }
    } catch (e) {
      print('[SignalR] Manual reconnect failed: $e');
      _isReconnecting = false;
      
      // Schedule another attempt if not too many attempts
      if (_reconnectAttempts < 10) {
        print('[SignalR] Scheduling retry attempt #${_reconnectAttempts + 1}...');
        
        // Only retry if still disconnected
        if (_hubConnection?.state != HubConnectionState.Connected) {
          _attemptReconnect();
        }
      } else {
        print('[SignalR] Max reconnect attempts reached. Giving up.');
        _reconnectAttempts = 0;
      }
    } finally {
      if (_hubConnection?.state == HubConnectionState.Connected) {
        _isReconnecting = false;
      }
    }
  }
  
  /// Perform incremental sync after reconnection to fetch missed events
  Future<void> _performIncrementalSync() async {
    if (_lastSyncTimestamp == null) {
      print('[SignalR] No last sync timestamp, skipping incremental sync');
      _lastSyncTimestamp = DateTime.now();
      return;
    }
    
    try {
      print('[SignalR] Performing incremental sync since ${_lastSyncTimestamp!.toIso8601String()}');
      
      // Call server method to get missed events
      await _hubConnection?.invoke(
        'IncrementalSync',
        args: [_lastSyncTimestamp!.toIso8601String()],
      );
      
      _lastSyncTimestamp = DateTime.now();
      print('[SignalR] Incremental sync completed');
    } catch (e) {
      print('[SignalR] Incremental sync failed: $e');
    }
  }
  
  /// Update last sync timestamp (call this periodically or after successful operations)
  void updateLastSyncTimestamp() {
    _lastSyncTimestamp = DateTime.now();
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
        
        // Update last sync timestamp
        updateLastSyncTimestamp();
        
        // Automatically send ACK
        try {
          await ackMessageReceived(message.id);
        } catch (e) {
          print('[SignalR] Failed to auto-send ACK: $e');
        }
      }
    });
  }
  
  /// Handle incremental sync result from server
  void onIncrementalSyncResult(Function(Map<String, dynamic>) callback) {
    _hubConnection?.off('IncrementalSyncResult');
    
    _hubConnection?.on('IncrementalSyncResult', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final syncData = arguments[0] as Map<String, dynamic>;
        print('[SignalR] Received incremental sync result: ${syncData['Messages']?.length ?? 0} messages, ${syncData['StatusUpdates']?.length ?? 0} status updates');
        callback(syncData);
        
        // Update last sync timestamp from server
        if (syncData['SyncTimestamp'] != null) {
          _lastSyncTimestamp = DateTime.parse(syncData['SyncTimestamp']);
        }
      }
    });
  }

  void onMessageStatusUpdated(Function(String messageId, MessageStatus status) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('MessageStatusUpdated');
    
    _hubConnection?.on('MessageStatusUpdated', (arguments) async {
      // #region agent log - Hypothesis D
      print('[DEBUG_MOBILE_STATUS_A] MessageStatusUpdated received at ${DateTime.now()}, args: $arguments');
      // #endregion
      if (arguments != null && arguments.length >= 2) {
        final messageId = arguments[0] as String;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        // #region agent log - Hypothesis D
        print('[DEBUG_MOBILE_STATUS_B] Parsed: messageId=$messageId, status=$status');
        // #endregion
        callback(messageId, status);
        
        // Automatically send ACK
        try {
          await ackStatusUpdate(messageId, statusIndex);
          // #region agent log - Hypothesis D
          print('[DEBUG_MOBILE_STATUS_C] ACK sent for status update');
          // #endregion
        } catch (e) {
          // #region agent log - Hypothesis D
          print('[DEBUG_MOBILE_STATUS_ERROR] Failed to auto-send status ACK: $e');
          // #endregion
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
    // #region agent log - Hypothesis E
    print('[DEBUG_MOBILE_ACK_A] markMessageAsDelivered called for message $messageId, chat $chatId at ${DateTime.now()}');
    // #endregion
    if (!isConnected) {
      // #region agent log - Hypothesis E
      print('[DEBUG_MOBILE_ACK_B] Cannot mark as delivered - not connected');
      // #endregion
      return;
    }
    
    try {
      await _hubConnection?.invoke('MessageDelivered', args: [messageId, chatId]);
      // #region agent log - Hypothesis E
      print('[DEBUG_MOBILE_ACK_C] Message marked as delivered successfully: $messageId');
      // #endregion
    } catch (e) {
      // #region agent log - Hypothesis E
      print('[DEBUG_MOBILE_ACK_ERROR] Failed to send delivery confirmation: $e');
      // #endregion
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
    _stopHeartbeatTimer();
    await _hubConnection?.stop();
  }

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
  
  /// Get heartbeat statistics for debugging
  Map<String, dynamic> getHeartbeatStats() {
    return {
      'isHeartbeatActive': _heartbeatTimer?.isActive ?? false,
      'lastPongReceived': _lastPongReceived?.toIso8601String(),
      'timeSinceLastPong': _lastPongReceived != null 
          ? DateTime.now().difference(_lastPongReceived!).inSeconds 
          : null,
    };
  }
}
