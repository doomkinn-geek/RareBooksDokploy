import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';

class SignalRService {
  HubConnection? _hubConnection;
  String? _currentToken;
  bool _isReconnecting = false;
  bool _isManualReconnecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastSyncTimestamp;
  Timer? _heartbeatTimer;
  DateTime? _lastPongReceived;
  Function()? _onReconnectedCallback;
  Function(bool isConnected)? _onConnectionStateChanged;
  
  // Connectivity monitoring
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _hasInternetConnection = true;
  
  // Infinite reconnect with capped exponential backoff
  static const int _maxReconnectDelay = 60; // Max delay capped at 60 seconds
  static const int _baseReconnectDelay = 2; // Start with 2 seconds
  Timer? _reconnectTimer;

  Future<void> connect(String token) async {
    // #region agent log - Hypothesis C: Track SignalR connect lifecycle
    print('[SIGNALR_CONNECT] HYP_C1: connect() called, timestamp: ${DateTime.now().toIso8601String()}');
    // #endregion
    _currentToken = token;
    
    // Start connectivity monitoring
    _startConnectivityMonitoring();
    
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          ApiConstants.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            transport: HttpTransportType.WebSockets,
            // Reduced timeout for faster reconnect
            requestTimeout: 3000, // 3 seconds (reduced from 30s)
          ),
        )
        // Faster retry intervals for better UX
        .withAutomaticReconnect(retryDelays: [0, 500, 1000, 2000, 5000])
        .build();

    // Обработчик разрыва соединения
    _hubConnection?.onclose(({error}) {
      // #region agent log - Hypothesis C
      print('[SIGNALR_CONNECT] HYP_C_CLOSE: Connection closed, error: $error, timestamp: ${DateTime.now().toIso8601String()}');
      // #endregion
      print('[SignalR] Connection closed. Error: $error');
      _isReconnecting = false;
      _isManualReconnecting = false;
      
      // Notify about disconnection
      _notifyConnectionState(false);
      
      // Stop heartbeat timer
      _stopHeartbeatTimer();
      
      // Automatic reconnect will be handled by withAutomaticReconnect
      // But if that fails completely, try manual reconnect with infinite retry
      if (_currentToken != null && _hasInternetConnection) {
        print('[SignalR] Scheduling manual reconnect attempt...');
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), () {
          if (_hubConnection?.state != HubConnectionState.Connected && 
              !_isReconnecting && 
              mounted) {
            _attemptReconnect();
          }
        });
      }
    });
    
    // Обработчик начала переподключения
    _hubConnection?.onreconnecting(({error}) {
      // #region agent log - Hypothesis C
      print('[SIGNALR_CONNECT] HYP_C_RECONNECTING: Reconnecting started, error: $error');
      // #endregion
      print('[SignalR] Reconnecting... Error: $error');
      _isReconnecting = true;
    });
    
    // Обработчик успешного переподключения
    _hubConnection?.onreconnected(({connectionId}) async {
      // #region agent log - Hypothesis C
      print('[SIGNALR_CONNECT] HYP_C_RECONNECTED: Reconnected successfully, connectionId: $connectionId');
      // #endregion
      print('[SignalR] Reconnected successfully! Connection ID: $connectionId');
      _isReconnecting = false;
      _isManualReconnecting = false;
      _reconnectAttempts = 0;
      
      // Cancel any pending reconnect timer
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      // Notify about successful connection
      _notifyConnectionState(true);
      
      // Restart heartbeat timer
      _startHeartbeatTimer();
      
      // Perform incremental sync after reconnection
      await _performIncrementalSync();
      
      // Trigger callback for additional sync operations (e.g., status sync)
      if (_onReconnectedCallback != null) {
        try {
          await _onReconnectedCallback!();
        } catch (e) {
          print('[SignalR] Error in reconnected callback: $e');
        }
      }
    });

    // Setup Pong handler before connecting
    _setupPongHandler();
    
    try {
      // #region agent log - Hypothesis C
      final startConnectTime = DateTime.now();
      // #endregion
      await _hubConnection?.start();
      // #region agent log - Hypothesis C
      final connectDuration = DateTime.now().difference(startConnectTime).inMilliseconds;
      print('[SIGNALR_CONNECT] HYP_C2: Connected successfully in ${connectDuration}ms, state: ${_hubConnection?.state}');
      // #endregion
      print('[SignalR] Connected successfully');
      
      // Notify about successful connection
      _notifyConnectionState(true);
      _reconnectAttempts = 0;
      
      // Start heartbeat timer after successful connection
      _startHeartbeatTimer();
    } catch (e) {
      // #region agent log - Hypothesis C
      print('[SIGNALR_CONNECT] HYP_C_ERROR: Failed to connect: $e');
      // #endregion
      print('[SignalR] Failed to connect: $e');
      _notifyConnectionState(false);
      
      // Schedule reconnect attempt
      if (_hasInternetConnection) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _attemptReconnect();
          }
        });
      }
      
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
  
  /// Quick health check to verify connection is still alive
  /// Returns true if connection is healthy, false otherwise
  Future<bool> _quickHealthCheck() async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      print('[SignalR] Health check: not connected');
      return false;
    }
    
    try {
      // Try a lightweight operation with short timeout
      // Note: This assumes the server has a Ping method, or we can use any lightweight method
      // If server doesn't have Ping, this will fail but it's okay - we'll proceed with reconnect
      await _hubConnection!.invoke('Ping').timeout(const Duration(seconds: 2));
      print('[SignalR] Health check passed, connection is healthy');
      return true;
    } catch (e) {
      print('[SignalR] Health check failed: $e');
      return false;
    }
  }
  
  /// Public method to force reconnect (e.g., when app returns from background)
  Future<void> forceReconnectFromLifecycle() async {
    print('[SignalR] Force reconnect requested from app lifecycle');
    
    // Quick health check first - if connection is healthy, skip reconnect
    if (await _quickHealthCheck()) {
      print('[SignalR] Connection healthy, skipping reconnect');
      return;
    }
    
    // Check current state
    final currentState = _hubConnection?.state;
    print('[SignalR] Current connection state: $currentState');
    
    if (currentState == HubConnectionState.Connected) {
      print('[SignalR] Already connected, no reconnect needed');
      return;
    }
    
    if (currentState == HubConnectionState.Reconnecting) {
      print('[SignalR] Already reconnecting, waiting for auto-reconnect');
      return;
    }
    
    // Only attempt manual reconnect if Disconnected
    _reconnectAttempts = 0; // Reset attempts for fresh start
    await _forceReconnect();
  }
  
  Future<void> _attemptReconnect() async {
    if (_currentToken == null || _isReconnecting || _isManualReconnecting) {
      print('[SignalR] Reconnect skipped - already reconnecting or no token');
      return;
    }
    
    // Check if we have internet connection
    if (!_hasInternetConnection) {
      print('[SignalR] No internet connection, waiting for connectivity...');
      _notifyConnectionState(false);
      return;
    }
    
    // Check if already connected or reconnecting
    final currentState = _hubConnection?.state;
    if (currentState == HubConnectionState.Connected) {
      print('[SignalR] Already connected, skipping reconnect');
      _notifyConnectionState(true);
      return;
    }
    
    if (currentState == HubConnectionState.Reconnecting) {
      print('[SignalR] Already reconnecting automatically, not interfering');
      return;
    }
    
    _isManualReconnecting = true;
    _reconnectAttempts++;
    print('[SignalR] Manual reconnect attempt #$_reconnectAttempts started');
    _notifyConnectionState(false);
    
    try {
      // Small delay to let automatic reconnect finish if it's in progress
      await Future.delayed(const Duration(seconds: 1));
      
      // Check state again after delay
      if (_hubConnection?.state == HubConnectionState.Connected) {
        print('[SignalR] Connection restored during wait, aborting manual reconnect');
        _reconnectAttempts = 0;
        _notifyConnectionState(true);
        return;
      }
      
      if (_hubConnection?.state == HubConnectionState.Reconnecting) {
        print('[SignalR] Auto-reconnect is active, letting it handle reconnection');
        return;
      }
      
      // If still disconnected after delay, try to restart the connection
      if (_hubConnection?.state == HubConnectionState.Disconnected) {
        print('[SignalR] Connection is Disconnected, attempting start()...');
        await _hubConnection?.start();
        print('[SignalR] Manual reconnect successful via start()');
        _reconnectAttempts = 0;
        _notifyConnectionState(true);
        _startHeartbeatTimer();
      }
    } catch (e) {
      print('[SignalR] Manual reconnect failed: $e');
      
      // INFINITE RETRY with exponential backoff (capped at _maxReconnectDelay)
      // Calculate delay: 2^attempts seconds, capped at max
      final retryDelay = min(
        _baseReconnectDelay * pow(2, min(_reconnectAttempts - 1, 6)).toInt(),
        _maxReconnectDelay
      );
      print('[SignalR] Scheduling retry attempt #${_reconnectAttempts + 1} in ${retryDelay}s...');
      
      // Cancel any existing timer
      _reconnectTimer?.cancel();
      
      // Schedule next attempt using Timer instead of Future.delayed for cancellation support
      _reconnectTimer = Timer(Duration(seconds: retryDelay), () {
        // Only retry if still disconnected and has internet
        if (_hubConnection?.state != HubConnectionState.Connected && 
            mounted && 
            _hasInternetConnection) {
          _isManualReconnecting = false; // Reset flag for retry
          _attemptReconnect();
        }
      });
    } finally {
      _isManualReconnecting = false;
      if (_hubConnection?.state == HubConnectionState.Connected) {
        _isReconnecting = false;
        _notifyConnectionState(true);
      }
    }
  }
  
  /// Start monitoring network connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    
    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      _hasInternetConnection = result != ConnectivityResult.none;
      print('[SignalR] Initial connectivity: $_hasInternetConnection (result: $result)');
    });
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasConnected = _hasInternetConnection;
      _hasInternetConnection = result != ConnectivityResult.none;
      
      print('[SignalR] Connectivity changed: $_hasInternetConnection (was: $wasConnected, result: $result)');
      
      // If we just got internet back and SignalR is disconnected, trigger reconnect
      if (!wasConnected && _hasInternetConnection) {
        print('[SignalR] Internet restored, triggering reconnect...');
        _reconnectAttempts = 0; // Reset attempts for fresh start
        
        // Small delay to let network stabilize
        Future.delayed(const Duration(seconds: 1), () {
          if (_hubConnection?.state != HubConnectionState.Connected && mounted) {
            _attemptReconnect();
          }
        });
      }
      
      // If we just lost internet, notify about disconnection
      if (wasConnected && !_hasInternetConnection) {
        print('[SignalR] Internet lost, notifying disconnection...');
        _notifyConnectionState(false);
      }
    });
  }
  
  /// Notify listeners about connection state changes
  void _notifyConnectionState(bool isConnected) {
    if (_onConnectionStateChanged != null) {
      try {
        _onConnectionStateChanged!(isConnected);
      } catch (e) {
        print('[SignalR] Error in connection state callback: $e');
      }
    }
  }
  
  /// Set callback for connection state changes
  void setOnConnectionStateChanged(Function(bool isConnected) callback) {
    _onConnectionStateChanged = callback;
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

  void onMessageStatusUpdated(Function(String messageId, MessageStatus status, String? chatId) callback) {
    // Отписываемся от предыдущего обработчика, если был
    _hubConnection?.off('MessageStatusUpdated');
    
    _hubConnection?.on('MessageStatusUpdated', (arguments) async {
      print('[STATUS_SYNC] MessageStatusUpdated received: $arguments');
      if (arguments != null && arguments.length >= 2) {
        final messageId = arguments[0] as String;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        // chatId is now sent as third argument for proper routing
        final chatId = arguments.length >= 3 ? arguments[2]?.toString() : null;
        
        print('[STATUS_SYNC] Parsed: messageId=$messageId, status=$status, chatId=$chatId');
        callback(messageId, status, chatId);
        
        // Automatically send ACK
        try {
          await ackStatusUpdate(messageId, statusIndex);
          print('[STATUS_SYNC] ACK sent for status update');
        } catch (e) {
          print('[STATUS_SYNC] Failed to auto-send status ACK: $e');
        }
      }
    });
  }

  /// Handle batch message status updates (optimized for multiple messages at once)
  void onBatchMessageStatusUpdated(Function(List<String> messageIds, MessageStatus status) callback) {
    _hubConnection?.off('BatchMessageStatusUpdated');
    
    _hubConnection?.on('BatchMessageStatusUpdated', (arguments) async {
      print('[SignalR] BatchMessageStatusUpdated received: $arguments');
      if (arguments != null && arguments.length >= 2) {
        final messageIdsList = arguments[0] as List;
        final statusIndex = arguments[1] as int;
        final status = MessageStatus.values[statusIndex];
        final messageIds = messageIdsList.map((id) => id.toString()).toList();
        
        print('[SignalR] Batch status update: ${messageIds.length} messages -> $status');
        callback(messageIds, status);
        
        // Send ACKs for all updated messages
        for (final messageId in messageIds) {
          try {
            await ackStatusUpdate(messageId, statusIndex);
        } catch (e) {
            print('[SignalR] Failed to ACK batch status for $messageId: $e');
          }
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
  
  /// Register callback for poll updates (voting, closing)
  void onPollUpdated(Function(String messageId, Map<String, dynamic> pollData) callback) {
    _hubConnection?.off('PollUpdated');
    
    _hubConnection?.on('PollUpdated', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        final messageId = data['MessageId']?.toString() ?? data['messageId']?.toString();
        final pollData = data['Poll'] ?? data['poll'];
        
        if (messageId != null && pollData != null) {
          print('[SignalR] Poll updated: messageId=$messageId');
          callback(messageId, Map<String, dynamic>.from(pollData));
        }
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

  /// Mark audio message as played
  Future<void> markAudioAsPlayed(String messageId, String chatId) async {
    if (!isConnected) {
      print('[SignalR] Cannot mark audio as played - not connected');
      return;
    }
    
    try {
      await _hubConnection?.invoke('MessagePlayed', args: [messageId, chatId]);
      print('[SignalR] Audio marked as played: $messageId');
    } catch (e) {
      print('[SignalR] Failed to mark audio as played: $e');
      // Fallback to REST API will be handled by StatusSyncService
    }
  }

  /// Request incremental sync after reconnection to get missed messages and status updates
  Future<void> requestIncrementalSync() async {
    if (!isConnected) {
      print('[SignalR] Cannot request incremental sync - not connected');
      return;
    }
    
    try {
      // Use last known sync timestamp (stored in service)
      final since = _lastSyncTimestamp ?? DateTime.now().subtract(const Duration(hours: 1));
      
      print('[SignalR] Requesting incremental sync since: $since');
      await _hubConnection?.invoke('RequestIncrementalSync', args: [since.toIso8601String()]);
      print('[SignalR] Incremental sync requested successfully');
    } catch (e) {
      print('[SignalR] Failed to request incremental sync: $e');
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

  /// activityType: 0 = typing text, 1 = recording audio
  void onUserTyping(Function(String chatId, String userId, String userName, bool isTyping, int activityType) callback) {
    _hubConnection?.off('UserTyping');
    
    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 4) {
        final userId = arguments[0] as String;
        final userName = arguments[1] as String;
        final isTyping = arguments[2] as bool;
        final chatId = arguments[3] as String;
        // activityType: 0 = typing text (default), 1 = recording audio
        final activityType = arguments.length >= 5 ? (arguments[4] as int? ?? 0) : 0;
        callback(chatId, userId, userName, isTyping, activityType);
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
    // #region agent log - Hypothesis C/D: Track joinChat calls
    print('[SIGNALR_JOIN] HYP_D_JOIN1: joinChat called - chatId: $chatId, isConnected: $isConnected, state: ${_hubConnection?.state}, timestamp: ${DateTime.now().toIso8601String()}');
    // #endregion
    if (!isConnected) {
      // #region agent log - Hypothesis C
      print('[SIGNALR_JOIN] HYP_C_NOT_CONNECTED: Cannot join chat - SignalR not connected');
      // #endregion
      print('[SignalR] Cannot join chat - not connected');
      return;
    }
    
    try {
      // #region agent log - Hypothesis D
      final joinStart = DateTime.now();
      // #endregion
      await _hubConnection?.invoke('JoinChat', args: [chatId]);
      // #region agent log - Hypothesis D
      final joinDuration = DateTime.now().difference(joinStart).inMilliseconds;
      print('[SIGNALR_JOIN] HYP_D_JOIN2: Joined chat in ${joinDuration}ms');
      // #endregion
      print('[SignalR] Joined chat: $chatId');
    } catch (e) {
      // #region agent log - Hypothesis C/D
      print('[SIGNALR_JOIN] HYP_D_JOIN_ERROR: Failed to join chat: $e');
      // #endregion
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
  
  /// Send activity indicator with type (0 = typing text, 1 = recording audio)
  Future<void> sendActivityIndicator(String chatId, bool isActive, int activityType) async {
    if (!isConnected) {
      return; // Не логируем - это не критично
    }
    
    try {
      await _hubConnection?.invoke('ActivityIndicator', args: [chatId, isActive, activityType]);
    } catch (e) {
      // Игнорируем ошибки activity indicator
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
  
  void onMessageEdited(Function(Map<String, dynamic>) callback) {
    _hubConnection?.off('MessageEdited');
    
    _hubConnection?.on('MessageEdited', (arguments) {
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _hubConnection?.stop();
    _notifyConnectionState(false);
  }

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
  
  /// Check if service is still active (for use in async operations)
  bool get mounted => _hubConnection != null;
  
  /// Set callback to be called after successful reconnection
  void setOnReconnectedCallback(Future<void> Function() callback) {
    _onReconnectedCallback = callback;
  }
  
  /// Get heartbeat statistics for debugging
  Map<String, dynamic> getHeartbeatStats() {
    return {
      'isHeartbeatActive': _heartbeatTimer?.isActive ?? false,
      'lastPongReceived': _lastPongReceived?.toIso8601String(),
      'timeSinceLastPong': _lastPongReceived != null 
          ? DateTime.now().difference(_lastPongReceived!).inSeconds 
          : null,
      'reconnectAttempts': _reconnectAttempts,
      'hasInternetConnection': _hasInternetConnection,
      'isReconnecting': _isReconnecting || _isManualReconnecting,
      'connectionState': _hubConnection?.state.toString(),
    };
  }
  
  /// Get current internet connection status
  bool get hasInternetConnection => _hasInternetConnection;
  
  /// Get current reconnect attempts count
  int get reconnectAttempts => _reconnectAttempts;
}
