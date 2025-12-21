import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart' as models;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  String? _currentChatId;
  Future<void> Function(String chatId, String? messageId)? onNotificationTap;
  Future<void> Function(String chatId, String text)? onNotificationReply;
  
  // Track notifications per chat for grouping
  final Map<String, List<String>> _notificationsByChat = {};
  final Map<String, int> _unreadCountByChat = {};

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          // Parse payload: "chatId|messageId" or just "chatId"
          final parts = response.payload!.split('|');
          final chatId = parts[0];
          final messageId = parts.length > 1 ? parts[1] : null;
          
          if (response.input != null && response.input!.isNotEmpty && onNotificationReply != null) {
            await onNotificationReply!(chatId, response.input!);
          } else if (onNotificationTap != null) {
            await onNotificationTap!(chatId, messageId);
          }
        }
      },
    );

    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void setCurrentChat(String? chatId) {
    _currentChatId = chatId;
    
    // Clear notifications for this chat when user enters it
    if (chatId != null && _notificationsByChat.containsKey(chatId)) {
      _notifications.cancel(chatId.hashCode);
      _notificationsByChat.remove(chatId);
      _unreadCountByChat.remove(chatId);
    }
  }

  Future<void> showMessageNotification(models.Message message, String chatTitle) async {
    // Не показываем уведомление если пользователь в текущем чате
    if (_currentChatId == message.chatId) {
      return;
    }

    // Track this notification
    if (!_notificationsByChat.containsKey(message.chatId)) {
      _notificationsByChat[message.chatId] = [];
      _unreadCountByChat[message.chatId] = 0;
    }
    
    final body = message.type == models.MessageType.text
        ? message.content ?? ''
        : '🎤 Голосовое сообщение';
    
    _notificationsByChat[message.chatId]!.add(body);
    _unreadCountByChat[message.chatId] = (_unreadCountByChat[message.chatId] ?? 0) + 1;
    
    final messageCount = _unreadCountByChat[message.chatId] ?? 1;
    final messages = _notificationsByChat[message.chatId] ?? [];
    
    // Create InboxStyle notification with all messages
    final inboxLines = messages.take(5).toList();

    final androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      groupKey: 'messages_group',
      styleInformation: InboxStyleInformation(
        inboxLines,
        contentTitle: messageCount > 1 
            ? '$messageCount new messages' 
            : chatTitle,
        summaryText: chatTitle,
      ),
      actions: [
        AndroidNotificationAction(
          'reply_action',
          'Ответить',
          inputs: [AndroidNotificationActionInput(label: 'Введите сообщение')],
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      message.chatId.hashCode,
      messageCount > 1 ? '$chatTitle ($messageCount)' : chatTitle,
      messageCount > 1 ? messages.last : body,
      notificationDetails,
      payload: '${message.chatId}|${message.id}', // Include messageId
    );
    
    // Show summary notification if multiple chats have unread messages
    if (_unreadCountByChat.length > 1) {
      await _showSummaryNotification();
    }
  }

  Future<void> _showSummaryNotification() async {
    try {
      final totalUnread = _unreadCountByChat.values.fold(0, (sum, count) => sum + count);
      final chatCount = _unreadCountByChat.length;
      
      final androidDetails = const AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'New message notifications',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'messages_group',
        setAsGroupSummary: true,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        0, // Summary notification ID
        'May Messenger',
        '$totalUnread new messages from $chatCount chats',
        notificationDetails,
      );
    } catch (e) {
      print('[NotificationService] Error showing summary notification: $e');
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

