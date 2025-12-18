import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/api_constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

// Global instance for background handler
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM_BG] Handling background message: ${message.messageId}');
  print('[FCM_BG] Data: ${message.data}');
  
  // Parse content from data payload (Data-only message)
  final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
  final body = message.data['body'] ?? message.notification?.body ?? '';
  final chatId = message.data['chatId'] as String?;
  
  // Show local notification
  try {
    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      actions: [
        AndroidNotificationAction(
          'reply_action',
          'Ответить',
          inputs: [AndroidNotificationActionInput(label: 'Введите сообщение')],
        ),
      ],
    );
    
    const notificationDetails = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      chatId.hashCode, // Use chatId hash as notification ID
      title,
      body,
      notificationDetails,
      payload: chatId,
    );
    
    print('[FCM_BG] Local notification shown');
  } catch (e) {
    print('[FCM_BG] Error showing notification: $e');
  }
}

class FcmService {
  FirebaseMessaging? _messaging;
  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? _currentChatId; // Track current open chat to suppress notifications
  Function(String chatId)? onMessageTap;
  Function(String chatId, String text)? onMessageReply;
  
  // Проверка поддержки Firebase на текущей платформе
  bool get _isFirebaseSupported => kIsWeb || Platform.isAndroid || Platform.isIOS;
  
  // Ленивая инициализация FirebaseMessaging только на поддерживаемых платформах
  FirebaseMessaging? get _messagingInstance {
    if (_isFirebaseSupported && _messaging == null) {
      _messaging = FirebaseMessaging.instance;
    }
    return _messaging;
  }
  
  void setCurrentChat(String? chatId) {
    _currentChatId = chatId;
    print('[FCM] Current chat set to: $chatId');
  }

  Future<void> initialize() async {
    // Пропускаем инициализацию на Desktop платформах
    if (!_isFirebaseSupported) {
      print('[FCM] Not supported on this platform (Desktop), skipping initialization');
      return;
    }
    
    // Initialize local notifications first
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('[FCM] Notification tapped with payload: ${response.payload}');
        if (response.payload != null) {
          if (response.input != null && response.input!.isNotEmpty && onMessageReply != null) {
             onMessageReply!(response.payload!, response.input!);
          } else if (onMessageTap != null) {
             onMessageTap!(response.payload!);
          }
        }
      },
    );
    
    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'messages_channel',
      'Messages',
      description: 'Notifications for new messages',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    print('[FCM] Local notifications initialized');
    
    // Инициализируем FirebaseMessaging через геттер
    final messaging = _messagingInstance;
    if (messaging == null) {
      print('[FCM] Failed to initialize FirebaseMessaging');
      return;
    }
    
    // Request permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] User granted permission');
      
      // Get FCM token
      _fcmToken = await messaging.getToken();
      print('[FCM] Token: $_fcmToken');
      
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle message tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Check if app was opened from notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      print('[FCM] User declined or has not accepted permission');
    }
  }

  Future<void> registerToken(String token) async {
    if (!_isFirebaseSupported || _fcmToken == null) return;
    
    try {
      final deviceInfo = await _getDeviceInfo();
      
      await _dio.post(
        '${ApiConstants.baseUrl}/api/notifications/register-token',
        data: {
          'token': _fcmToken,
          'deviceInfo': deviceInfo,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('FCM token registered successfully');
    } catch (e) {
      print('Failed to register FCM token: $e');
    }
  }

  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} - ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return 'Windows ${windowsInfo.productName}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'macOS ${macInfo.osRelease}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return 'Linux ${linuxInfo.name}';
      } else {
        return 'Unknown Platform';
      }
    } catch (e) {
      print('Failed to get device info: $e');
      return 'Unknown Device';
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    print('[FCM_FG] Foreground message data: ${message.data}');
    
    // Parse content from data payload
    final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
    final body = message.data['body'] ?? message.notification?.body ?? '';
    final chatId = message.data['chatId'] as String?;
    
    // Don't show notification if user is currently in this chat
    if (chatId != null && chatId == _currentChatId) {
      print('[FCM_FG] User in current chat, not showing notification');
      return;
    }
    
    // Show local notification
    try {
      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        actions: [
          AndroidNotificationAction(
            'reply_action',
            'Ответить',
            inputs: [AndroidNotificationActionInput(label: 'Введите сообщение')],
          ),
        ],
      );
      
      const notificationDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        chatId.hashCode, // Use chatId hash as notification ID
        title,
        body,
        notificationDetails,
        payload: chatId,
      );
      
      print('[FCM_FG] Local notification shown');
    } catch (e) {
      print('[FCM_FG] Error showing notification: $e');
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('[FCM] Message opened app: ${message.data}');
    final chatId = message.data['chatId'] as String?;
    if (chatId != null && onMessageTap != null) {
      onMessageTap!(chatId);
    }
  }

  String? get fcmToken => _fcmToken;
}

