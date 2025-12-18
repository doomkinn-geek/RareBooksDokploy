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
  Future<void> Function(String chatId, String text)? onNotificationReply;

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
          if (response.input != null && response.input!.isNotEmpty && onNotificationReply != null) {
            await onNotificationReply!(response.payload!, response.input!);
          } else if (onNotificationTap != null) {
            await onNotificationTap!(response.payload!);
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
  }

  Future<void> showMessageNotification(models.Message message, String chatTitle) async {
    // Не показываем уведомление если пользователь в текущем чате
    if (_currentChatId == message.chatId) {
      return;
    }

    // Используем chatId как ID уведомления для группировки сообщений из одного чата
    // Это заменит предыдущее уведомление из того же чата
    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      groupKey: 'messages_group', // Группировка для Android
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

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = message.type == models.MessageType.text
        ? message.content
        : '🎤 Голосовое сообщение';

    // Используем chatId.hashCode вместо message.id.hashCode
    // Это приведет к тому, что новые сообщения из одного чата будут заменять предыдущие
    await _notifications.show(
      message.chatId.hashCode,
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

