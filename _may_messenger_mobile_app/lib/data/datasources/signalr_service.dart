import 'package:signalr_netcore/signalr_client.dart';
import '../models/message_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/logger_service.dart';

class SignalRService {
  HubConnection? _hubConnection;
  final _logger = LoggerService();

  Future<void> connect(String token) async {
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

    await _hubConnection?.start();
  }

  void onReceiveMessage(Function(Message) callback) {
    _hubConnection?.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageJson = arguments[0] as Map<String, dynamic>;
        final message = Message.fromJson(messageJson);
        callback(message);
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

  Future<void> markMessageAsDelivered(String messageId, String chatId) async {
    try {
      await _hubConnection?.invoke('MessageDelivered', args: [messageId, chatId]);
    } catch (e) {
      print('Failed to send delivery confirmation: $e');
    }
  }

  Future<void> markMessageAsRead(String messageId, String chatId) async {
    await _hubConnection?.invoke('MessageRead', args: [messageId, chatId]);
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

  void onNewChatCreated(Function() callback) {
    _hubConnection?.on('NewChatCreated', (arguments) {
      // When a new chat is created, just trigger refresh
      callback();
    });
  }

  Future<void> joinChat(String chatId) async {
    await _hubConnection?.invoke('JoinChat', args: [chatId]);
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

  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    await _hubConnection?.invoke('TypingIndicator', args: [chatId, isTyping]);
  }

  void onMessageDeleted(Function(Map<String, dynamic>) callback) {
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
