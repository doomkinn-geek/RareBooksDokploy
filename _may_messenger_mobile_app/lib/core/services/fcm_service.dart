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
  Function(String messageId, String chatId)? onMessageReceived; // Callback to fetch message
  
  // Track notifications per chat for grouping
  final Map<String, List<String>> _notificationsByChat = {};
  final Map<String, int> _unreadCountByChat = {};
  
  // Track already confirmed deliveries to avoid duplicates
  final Set<String> _confirmedDeliveries = {};
  
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
    if (chatId != null) {
      clearChatNotifications(chatId);
    }
  }
  
  /// Clear notifications and badge for a specific chat
  /// Call this when user opens a chat
  Future<void> clearChatNotifications(String chatId) async {
    try {
      // Cancel local notification for this chat
      await _localNotifications.cancel(chatId.hashCode);
      
      // Clear tracking data
      _notificationsByChat.remove(chatId);
      _unreadCountByChat.remove(chatId);
      
      // Update summary notification if needed
      if (_unreadCountByChat.isNotEmpty) {
        await _showSummaryNotification();
      } else {
        // Cancel summary notification if no more unread chats
        await _localNotifications.cancel(0);
      }
      
      // Clear badge on iOS
      if (Platform.isIOS) {
        await clearBadge();
      }
      
      print('[FCM] Cleared notifications for chat: $chatId');
    } catch (e) {
      print('[FCM] Error clearing chat notifications: $e');
    }
  }
  
  /// Clear all notifications and badge
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      _notificationsByChat.clear();
      _unreadCountByChat.clear();
      
      // Clear badge on iOS
      if (Platform.isIOS) {
        await clearBadge();
      }
      
      print('[FCM] Cleared all notifications');
    } catch (e) {
      print('[FCM] Error clearing all notifications: $e');
    }
  }
  
  /// Clear badge count on iOS
  Future<void> clearBadge() async {
    if (!Platform.isIOS) return;
    
    try {
      // Use iOS-specific implementation to reset badge to 0
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        // Show empty notification to reset badge, then immediately cancel it
        // This is a workaround for resetting the badge count
        await _localNotifications.show(
          -1, // Special ID for badge reset
          null,
          null,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentSound: false,
              presentBadge: true,
              badgeNumber: 0,
            ),
          ),
        );
        await _localNotifications.cancel(-1);
      }
      
      print('[FCM] Badge cleared on iOS');
    } catch (e) {
      print('[FCM] Error clearing badge: $e');
    }
  }

  Future<void> initialize() async {
    // Пропускаем инициализацию на Desktop платформах
    if (!_isFirebaseSupported) {
      print('[FCM] Not supported on this platform (Desktop), skipping initialization');
      return;
    }
    
    // Initialize local notifications first
    // Note: Using mipmap launcher icon for maximum compatibility
    // Custom notification icon requires PNG files in drawable-* folders
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
        print('[FCM] Notification response received: payload=${response.payload}');
        
        // Only handle tap action - reply functionality removed
        if (response.payload != null && onMessageTap != null) {
          print('[FCM] Tap action, opening chat');
          onMessageTap!(response.payload!);
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
    // Store JWT token for later auto-registration
    _jwtToken = token;
    
    if (!_isFirebaseSupported) {
      return;
    }
    
    // If FCM token is not available yet, wait for it
    if (_fcmToken == null) {
      // Try to get token again (in case it's available now)
      final messaging = _messagingInstance;
      if (messaging != null) {
        try {
          _fcmToken = await messaging.getToken();
        } catch (e) {
          print('[FCM] Retry getToken failed: $e');
        }
      }
      
      // If still null, token will be registered automatically when onTokenRefresh fires
      if (_fcmToken == null) {
        return;
      }
    }
    
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
      
      print('[FCM] Token registered successfully');
    } catch (e) {
      print('[FCM] Failed to register FCM token: $e');
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
    print('[FCM_FG] Notification payload: ${message.notification?.title}, ${message.notification?.body}');
    
    // Parse content from data payload
    final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
    final body = message.data['body'] ?? message.notification?.body ?? '';
    final chatId = message.data['chatId'] as String?;
    final messageId = message.data['messageId'] as String?;
    
    // IMPORTANT: Confirm delivery when push is received
    // This sends an HTTP confirmation to backend that push was delivered
    if (messageId != null && chatId != null) {
      await _confirmPushDelivery(messageId, chatId);
    }
    
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
    
    // iOS FIX: Don't show local notification if APNs already showed system notification
    // On iOS, when app is in foreground and message has notification payload,
    // APNs automatically displays it - we don't need to show another one
    if (Platform.isIOS && message.notification != null) {
      print('[FCM_FG] iOS: Skipping local notification (APNs alert already shown)');
      return;
    }
    
    // Show grouped notification
    // Android receives data-only messages (no notification payload from server)
    if (chatId != null) {
      await _showGroupedNotification(chatId, title, body);
    }
  }
  
  /// Confirm push delivery to backend via HTTP
  /// This ensures the sender sees "delivered" status even if SignalR is not connected
  Future<void> _confirmPushDelivery(String messageId, String chatId) async {
    // Skip if already confirmed
    if (_confirmedDeliveries.contains(messageId)) {
      print('[FCM] Delivery already confirmed for message: $messageId');
      return;
    }
    
    if (_jwtToken == null) {
      print('[FCM] Cannot confirm delivery - no JWT token');
      return;
    }
    
    try {
      print('[FCM] Confirming push delivery for message: $messageId, chat: $chatId');
      
      await _dio.post(
        '${ApiConstants.baseUrl}/api/messages/confirm-push-delivery',
        data: {
          'messageId': messageId,
          'chatId': chatId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_jwtToken'},
        ),
      );
      
      _confirmedDeliveries.add(messageId);
      
      // Limit cache size
      if (_confirmedDeliveries.length > 1000) {
        _confirmedDeliveries.clear();
      }
      
      print('[FCM] Push delivery confirmed for message: $messageId');
    } catch (e) {
      print('[FCM] Failed to confirm push delivery: $e');
      // Don't throw - this is best effort
    }
  }
  
  /// Static method for confirming delivery from background handler
  /// Uses provided token since service instance may not be available
  static Future<void> confirmPushDeliveryStatic(String messageId, String chatId, String jwtToken) async {
    try {
      final dio = Dio();
      
      print('[FCM_BG] Confirming push delivery for message: $messageId');
      
      await dio.post(
        '${ApiConstants.baseUrl}/api/messages/confirm-push-delivery',
        data: {
          'messageId': messageId,
          'chatId': chatId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $jwtToken'},
        ),
      );
      
      print('[FCM_BG] Push delivery confirmed for message: $messageId');
    } catch (e) {
      print('[FCM_BG] Failed to confirm push delivery: $e');
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
      
      // Calculate total unread count for badge
      final totalUnread = _unreadCountByChat.values.fold(0, (sum, count) => sum + count);
      
      // Create InboxStyle notification with all messages for this chat
      final inboxLines = messages.take(5).map((msg) => msg).toList();
      
      final androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        groupKey: 'chat_$chatId', // Group by chat, not globally
        styleInformation: InboxStyleInformation(
          inboxLines,
          contentTitle: messageCount > 1 
              ? '$title ($messageCount сообщений)' 
              : title,
          summaryText: title,
        ),
      );
      
      // iOS-specific settings with thread identifier for grouping
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        badgeNumber: totalUnread, // Show total unread count as badge
        threadIdentifier: 'chat_$chatId', // Group notifications by chat on iOS
        subtitle: messageCount > 1 ? '$messageCount сообщений' : null,
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Use chatId hash as notification ID - this REPLACES previous notification for same chat
      await _localNotifications.show(
        chatId.hashCode,
        messageCount > 1 ? '$title ($messageCount)' : title,
        messageCount > 1 ? '${messages.last}' : body,
        notificationDetails,
        payload: chatId, // IMPORTANT: payload is chatId for navigation
      );
      
      print('[FCM_FG] Grouped notification shown for chat $chatId ($messageCount messages, badge: $totalUnread)');
    } catch (e) {
      print('[FCM_FG] Error showing grouped notification: $e');
    }
  }

  Future<void> _showSummaryNotification() async {
    // Summary notification is only needed for Android notification grouping
    if (!Platform.isAndroid) return;
    
    try {
      final totalUnread = _unreadCountByChat.values.fold(0, (sum, count) => sum + count);
      final chatCount = _unreadCountByChat.length;
      
      if (chatCount <= 1) {
        // No need for summary if only one chat
        await _localNotifications.cancel(0);
        return;
      }
      
      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.low, // Low importance for summary
        priority: Priority.low,
        groupKey: 'messages_summary',
        setAsGroupSummary: true,
        onlyAlertOnce: true,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        0, // Summary notification ID
        'Депеша',
        '$totalUnread сообщений из $chatCount чатов',
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

