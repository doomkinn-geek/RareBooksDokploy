import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart' as models;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  String? _currentChatId;
  Future<void> Function(String chatId)? onNotificationTap;

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
        if (response.payload != null && onNotificationTap != null) {
          await onNotificationTap!(response.payload!);
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
  }

  Future<void> showMessageNotification(models.Message message, String chatTitle) async {
    // Не показываем уведомление если пользователь в текущем чате
    if (_currentChatId == message.chatId) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = message.type == models.MessageType.text
        ? message.content
        : '🎤 Голосовое сообщение';

    await _notifications.show(
      message.id.hashCode,
      chatTitle,
      body,
      notificationDetails,
      payload: message.chatId,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

