import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  FirebaseMessaging? _messaging;
  final Dio _dio = Dio();
  
  String? _fcmToken;
  Function(String chatId)? onMessageTap;
  
  // Проверка поддержки Firebase на текущей платформе
  bool get _isFirebaseSupported => kIsWeb || Platform.isAndroid || Platform.isIOS;
  
  // Ленивая инициализация FirebaseMessaging только на поддерживаемых платформах
  FirebaseMessaging? get _messagingInstance {
    if (_isFirebaseSupported && _messaging == null) {
      _messaging = FirebaseMessaging.instance;
    }
    return _messaging;
  }

  Future<void> initialize() async {
    // Пропускаем инициализацию на Desktop платформах
    if (!_isFirebaseSupported) {
      print('FCM not supported on this platform (Desktop), skipping initialization');
      return;
    }
    
    // Инициализируем FirebaseMessaging через геттер
    final messaging = _messagingInstance;
    if (messaging == null) {
      print('Failed to initialize FirebaseMessaging');
      return;
    }
    
    // Request permission - используем non-null assertion после проверки
    final settings = await messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get FCM token
      _fcmToken = await messaging!.getToken();
      print('FCM Token: $_fcmToken');
      
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle message tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Check if app was opened from notification
      final initialMessage = await messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      print('User declined or has not accepted permission');
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

