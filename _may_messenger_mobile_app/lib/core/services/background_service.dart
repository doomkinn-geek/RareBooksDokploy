import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/signalr_service.dart';
import '../constants/storage_keys.dart';

/// Background service for maintaining SignalR connection when app is in background
class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[BackgroundService] Already initialized');
      return;
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'messenger_background_service',
        initialNotificationTitle: 'Депеша',
        initialNotificationContent: 'Поддержание соединения...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    _isInitialized = true;
    print('[BackgroundService] Initialized');
  }

  /// Start background service (call when app goes to background)
  Future<void> startService() async {
    if (!_isInitialized) {
      await initialize();
    }

    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      print('[BackgroundService] Started');
    } else {
      print('[BackgroundService] Already running');
    }
  }

  /// Stop background service (call when app comes to foreground)
  Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stop');
      print('[BackgroundService] Stopped');
    }
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// Request immediate reconnect from background service
  void requestReconnect() {
    _service.invoke('reconnect');
  }

  /// Update service notification
  void updateNotification(String title, String content) {
    _service.invoke('update', {
      'title': title,
      'content': content,
    });
  }
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  print('[BackgroundService] onStart called');

  SignalRService? signalRService;
  Timer? heartbeatTimer;
  String? authToken;

  // Get auth token from storage
  try {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(StorageKeys.authToken);
    print('[BackgroundService] Token loaded: ${authToken != null ? "yes" : "no"}');
  } catch (e) {
    print('[BackgroundService] Failed to load token: $e');
  }

  // Initialize SignalR if we have a token
  if (authToken != null) {
    try {
      signalRService = SignalRService();
      await signalRService.connect(authToken);
      print('[BackgroundService] SignalR connected');
    } catch (e) {
      print('[BackgroundService] Failed to connect SignalR: $e');
    }
  }

  // Android-specific: set as foreground service
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Listen for stop command
  service.on('stop').listen((event) async {
    print('[BackgroundService] Stop requested');
    heartbeatTimer?.cancel();
    await signalRService?.disconnect();
    await service.stopSelf();
  });

  // Listen for reconnect command
  service.on('reconnect').listen((event) async {
    print('[BackgroundService] Reconnect requested');
    if (signalRService != null && authToken != null) {
      try {
        await signalRService.forceReconnectFromLifecycle();
        print('[BackgroundService] Reconnect completed');
      } catch (e) {
        print('[BackgroundService] Reconnect failed: $e');
      }
    }
  });

  // Listen for notification update
  service.on('update').listen((event) {
    if (service is AndroidServiceInstance) {
      if (event != null) {
        final title = event['title'] ?? 'Депеша';
        final content = event['content'] ?? 'Соединение активно';
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    }
  });

  // Start heartbeat timer - send heartbeat every 25 seconds
  heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) async {
    print('[BackgroundService] Heartbeat tick');
    
    if (signalRService == null || !signalRService.isConnected) {
      print('[BackgroundService] Not connected, attempting reconnect...');
      
      // Try to reconnect
      if (authToken != null && signalRService != null) {
        try {
          await signalRService.forceReconnectFromLifecycle();
          print('[BackgroundService] Reconnected successfully');
          
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Депеша',
              content: 'Соединение восстановлено',
            );
          }
        } catch (e) {
          print('[BackgroundService] Reconnect failed: $e');
          
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Депеша',
              content: 'Переподключение...',
            );
          }
        }
      }
    } else {
      // Connection is alive, update notification
      if (service is AndroidServiceInstance) {
        final stats = signalRService.getHeartbeatStats();
        final lastPong = stats['timeSinceLastPong'] as int?;
        
        if (lastPong != null && lastPong > 60) {
          service.setForegroundNotificationInfo(
            title: 'Депеша',
            content: 'Проверка соединения...',
          );
        } else {
          service.setForegroundNotificationInfo(
            title: 'Депеша',
            content: 'Соединение активно',
          );
        }
      }
    }
  });

  // Keep the service running
  print('[BackgroundService] Service started successfully');
}

