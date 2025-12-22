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

// Background handler has been moved to main.dart
// It MUST be registered in main() before runApp() per Flutter Firebase Messaging docs

class FcmService {
  FirebaseMessaging? _messaging;
  final Dio _dio = Dio();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? _currentChatId; // Track current open chat to suppress notifications
  String? _jwtToken; // Store JWT token for auto-registration
  Function(String chatId)? onMessageTap;
  Function(String chatId, String text)? onMessageReply;
  Function(String messageId, String chatId)? onMessageReceived; // Callback to fetch message
  
  // Track notifications per chat for grouping
  final Map<String, List<String>> _notificationsByChat = {};
  final Map<String, int> _unreadCountByChat = {};
  
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
    
    // Clear notifications for this chat when user enters it
    if (chatId != null && _notificationsByChat.containsKey(chatId)) {
      _localNotifications.cancel(chatId.hashCode);
      _notificationsByChat.remove(chatId);
      _unreadCountByChat.remove(chatId);
    }
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
      
      // Get FCM token (may be null on first app launch)
      _fcmToken = await messaging.getToken();
      print('[FCM] Initial token: $_fcmToken');
      
      // Listen for token refresh/updates
      messaging.onTokenRefresh.listen((newToken) {
        print('[FCM] Token refreshed: $newToken');
        _fcmToken = newToken;
        
        // Auto-register new token if we have JWT token
        if (_jwtToken != null) {
          print('[FCM] Auto-registering refreshed token');
          registerToken(_jwtToken!).catchError((e) {
            print('[FCM] Failed to auto-register token: $e');
          });
        }
      });
      
      // Background handler is now registered in main.dart (before runApp)
      // This is required by Flutter Firebase Messaging documentation
      
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
    // #region agent log - Hypothesis A
    print('[DEBUG_MOBILE_FCM_A] registerToken called at ${DateTime.now()}');
    // #endregion
    
    // Store JWT token for later auto-registration
    _jwtToken = token;
    
    if (!_isFirebaseSupported) {
      // #region agent log - Hypothesis A
      print('[DEBUG_MOBILE_FCM_B] Firebase not supported on this platform');
      // #endregion
      return;
    }
    
    // If FCM token is not available yet, wait for it
    if (_fcmToken == null) {
      // #region agent log - Hypothesis A
      print('[DEBUG_MOBILE_FCM_C] FCM token not available yet, waiting...');
      // #endregion
      
      // Try to get token again (in case it's available now)
      final messaging = _messagingInstance;
      if (messaging != null) {
        try {
          _fcmToken = await messaging.getToken();
          print('[FCM] Retry getToken result: ${_fcmToken != null ? 'success' : 'still null'}');
        } catch (e) {
          print('[FCM] Retry getToken failed: $e');
        }
      }
      
      // If still null, token will be registered automatically when onTokenRefresh fires
      if (_fcmToken == null) {
        print('[FCM] FCM token still null, will auto-register when available via onTokenRefresh');
        return;
      }
    }
    
    try {
      final deviceInfo = await _getDeviceInfo();
      
      // #region agent log - Hypothesis A
      print('[DEBUG_MOBILE_FCM_D] Sending registerToken request. Token: ${_fcmToken?.substring(0, 20)}..., DeviceInfo: $deviceInfo');
      // #endregion
      
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/api/notifications/register-token',
        data: {
          'token': _fcmToken,
          'deviceInfo': deviceInfo,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      // #region agent log - Hypothesis A
      print('[DEBUG_MOBILE_FCM_E] Token registered successfully: ${response.statusCode}, ${response.data}');
      // #endregion
    } catch (e) {
      // #region agent log - Hypothesis A
      print('[DEBUG_MOBILE_FCM_ERROR] Failed to register FCM token: $e');
      // #endregion
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
    final messageId = message.data['messageId'] as String?;
    
    // Trigger message fetch callback to ensure message is loaded
    if (messageId != null && chatId != null && onMessageReceived != null) {
      print('[FCM_FG] Triggering message fetch for messageId: $messageId');
      try {
        onMessageReceived!(messageId, chatId);
      } catch (e) {
        print('[FCM_FG] Error fetching message: $e');
      }
    }
    
    // Don't show notification if user is currently in this chat
    if (chatId != null && chatId == _currentChatId) {
      print('[FCM_FG] User in current chat, not showing notification');
      return;
    }
    
    if (chatId != null) {
      await _showGroupedNotification(chatId, title, body);
    }
  }

  Future<void> _showGroupedNotification(String chatId, String title, String body) async {
    try {
      // Track this notification
      if (!_notificationsByChat.containsKey(chatId)) {
        _notificationsByChat[chatId] = [];
        _unreadCountByChat[chatId] = 0;
      }
      
      _notificationsByChat[chatId]!.add(body);
      _unreadCountByChat[chatId] = (_unreadCountByChat[chatId] ?? 0) + 1;
      
      final messageCount = _unreadCountByChat[chatId] ?? 1;
      final messages = _notificationsByChat[chatId] ?? [];
      
      // Create InboxStyle notification with all messages
      final inboxLines = messages.take(5).map((msg) => msg).toList();
      
      final androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        groupKey: 'messages_group',
        styleInformation: InboxStyleInformation(
          inboxLines,
          contentTitle: messageCount > 1 
              ? '$messageCount new messages' 
              : title,
          summaryText: title,
        ),
        actions: [
          AndroidNotificationAction(
            'reply_action',
            'Ответить',
            inputs: [AndroidNotificationActionInput(label: 'Введите сообщение')],
          ),
        ],
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        chatId.hashCode, // Use chatId hash as notification ID (replaces previous)
        messageCount > 1 ? '$messageCount new messages' : title,
        messageCount > 1 ? messages.last : body,
        notificationDetails,
        payload: chatId,
      );
      
      // Show summary notification if multiple chats have unread messages
      if (_unreadCountByChat.length > 1) {
        await _showSummaryNotification();
      }
      
      print('[FCM_FG] Grouped notification shown for chat $chatId ($messageCount messages)');
    } catch (e) {
      print('[FCM_FG] Error showing grouped notification: $e');
    }
  }

  Future<void> _showSummaryNotification() async {
    try {
      final totalUnread = _unreadCountByChat.values.fold(0, (sum, count) => sum + count);
      final chatCount = _unreadCountByChat.length;
      
      final androidDetails = const AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'messages_group',
        setAsGroupSummary: true,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        0, // Summary notification ID
        'Депеша',
        '$totalUnread new messages from $chatCount chats',
        notificationDetails,
      );
      
      print('[FCM] Summary notification shown: $totalUnread messages from $chatCount chats');
    } catch (e) {
      print('[FCM] Error showing summary notification: $e');
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

