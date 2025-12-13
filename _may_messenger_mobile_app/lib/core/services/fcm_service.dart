import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  print('Handling background message: ${message.messageId}');
}

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Dio _dio = Dio();
  
  String? _fcmToken;
  Function(String chatId)? onMessageTap;

  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get FCM token
      _fcmToken = await _messaging.getToken();
      print('FCM Token: $_fcmToken');
      
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle message tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Check if app was opened from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> registerToken(String userId, String token) async {
    if (_fcmToken == null) return;
    
    try {
      await _dio.post(
        '${ApiConstants.baseUrl}/api/notifications/register-token',
        data: {
          'userId': userId,
          'token': _fcmToken,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } catch (e) {
      print('Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');
    // Notification will be handled by NotificationService through SignalR
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final chatId = message.data['chatId'] as String?;
    if (chatId != null && onMessageTap != null) {
      onMessageTap!(chatId);
    }
  }

  String? get fcmToken => _fcmToken;
}

