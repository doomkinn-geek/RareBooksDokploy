import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/themes/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/signalr_provider.dart';
import 'presentation/providers/chats_provider.dart';
import 'presentation/providers/messages_provider.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/chat_screen.dart';

// Global navigator key for navigation from FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global instance for background handler
final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

// CRITICAL: Background handler MUST be top-level function
// Must be registered in main() BEFORE runApp()
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM_BG] Handling background message: ${message.messageId}');
  print('[FCM_BG] Data: ${message.data}');
  
  // Parse content from data payload (Data-only message)
  final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
  final body = message.data['body'] ?? message.notification?.body ?? '';
  final chatId = message.data['chatId'] as String?;
  
  // Show local notification with grouping support
  try {
    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      groupKey: 'messages_group', // Group all messages together
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
      chatId.hashCode, // Use chatId hash as notification ID (one per chat)
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize Firebase только на поддерживаемых платформах (Android, iOS, Web)
  // На Desktop (Windows, Linux, macOS) Firebase пропускаем
  final shouldInitFirebase = kIsWeb || Platform.isAndroid || Platform.isIOS;
  
  if (shouldInitFirebase) {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
      
      // CRITICAL: Register background message handler BEFORE runApp()
      // This MUST be done here, not in FcmService.initialize()
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      print('[FCM] Background handler registered in main()');
      
      // Request PUSH notification permissions immediately on app start
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        print('[FCM] Permission status: ${settings.authorizationStatus}');
      } catch (e) {
        print('[FCM] Failed to request permissions: $e');
      }
    } catch (e) {
      print('Firebase initialization failed (may be not configured): $e');
    }
  } else {
    print('Firebase skipped on desktop platform (not required for local testing)');
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  DateTime? _lastPausedAt;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[LIFECYCLE] App state changed to: $state');
    
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
      print('[LIFECYCLE] App paused at $_lastPausedAt - SignalR will try to maintain connection');
    } else if (state == AppLifecycleState.resumed) {
      final authState = ref.read(authStateProvider);
      
      if (authState.isAuthenticated) {
        final pauseDuration = _lastPausedAt != null 
            ? DateTime.now().difference(_lastPausedAt!)
            : Duration.zero;
        
        print('[LIFECYCLE] App resumed after ${pauseDuration.inSeconds}s pause');
        
        // If app was in background > 30 seconds, do full reconnect + sync
        if (pauseDuration.inSeconds > 30) {
          print('[LIFECYCLE] Long pause detected, performing full resume sync');
          _performResumeSync();
        } else {
          // Short pause, just check connection
          print('[LIFECYCLE] Short pause, checking SignalR connection');
          final signalRState = ref.read(signalRConnectionProvider);
          
          if (!signalRState.isConnected) {
            print('[LIFECYCLE] SignalR disconnected - attempting reconnect');
            ref.read(signalRConnectionProvider.notifier).reconnect();
          } else {
            print('[LIFECYCLE] SignalR already connected');
          }
        }
      }
    }
  }
  
  Future<void> _performResumeSync() async {
    try {
      print('[LIFECYCLE] Starting resume sync sequence');
      
      // 1. Reconnect SignalR
      print('[LIFECYCLE] Step 1: Reconnecting SignalR');
      await ref.read(signalRConnectionProvider.notifier).reconnect();
      
      // Small delay to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 2. Force sync pending status updates
      print('[LIFECYCLE] Step 2: Syncing pending status updates');
      final statusSyncService = ref.read(statusSyncServiceProvider);
      await statusSyncService.forceSync();
      
      // 3. Refresh chats list to get updated unreads
      print('[LIFECYCLE] Step 3: Refreshing chats list');
      await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      
      print('[LIFECYCLE] Resume sync completed successfully');
    } catch (e) {
      print('[LIFECYCLE] Error during resume sync: $e');
      // Non-fatal, app will continue to work
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    // Initialize SignalR and services when authenticated
    if (authState.isAuthenticated) {
      // Важно: восстанавливаем токен в ApiDataSource перед любыми запросами
      Future.microtask(() async {
        try {
          // Восстанавливаем токен в ApiDataSource
          final authRepo = ref.read(authRepositoryProvider);
          final apiDataSource = ref.read(apiDataSourceProvider);
          final token = await authRepo.getStoredToken();
          
          if (token != null) {
            apiDataSource.setToken(token);
            print('Token restored to ApiDataSource: ${token.substring(0, 20)}...');
          } else {
            print('Warning: No token found to restore');
          }
        } catch (e) {
          print('Error restoring token: $e');
        }
      });
      
      ref.read(signalRConnectionProvider);
      
      // Initialize notification service
      Future.microtask(() async {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.initialize();
        
        // Setup local notification navigation callback
        notificationService.onNotificationTap = (chatId, messageId) async {
          print('[NOTIFICATION] Local notification tapped for chat: $chatId, message: $messageId');
          
          try {
            // STEP 1: Refresh chats list to ensure chat exists
            print('[NOTIFICATION] Refreshing chats list...');
            await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
            
            // STEP 2: Force refresh messages for this chat to show new message
            print('[NOTIFICATION] Loading messages for chat $chatId...');
            await ref.read(messagesProvider(chatId).notifier).loadMessages(forceRefresh: true);
            
            // STEP 3: Wait a bit to ensure messages are loaded
            await Future.delayed(const Duration(milliseconds: 300));
            
            // STEP 4: Navigate to chat screen with messageId for highlighting
            print('[NOTIFICATION] Navigating to chat screen...');
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  highlightMessageId: messageId,
                ),
              ),
              (route) => route.isFirst, // Keep only the main screen in stack
            );
            
            print('[NOTIFICATION] Navigation completed');
          } catch (e) {
            print('[NOTIFICATION] Error handling notification tap: $e');
            // Try to navigate anyway
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  highlightMessageId: messageId,
                ),
              ),
            );
          }
        };

        notificationService.onNotificationReply = (chatId, text) async {
          print('[NOTIFICATION] Reply received for chat $chatId: $text');
          try {
            if (text.trim().isEmpty) {
              print('[NOTIFICATION] Empty reply text, ignoring');
              return;
            }
            
            await ref.read(messagesProvider(chatId).notifier).sendMessage(text);
            print('[NOTIFICATION] Reply sent successfully');
            
            // Clear the notification after reply
            notificationService.setCurrentChat(chatId);
            await Future.delayed(const Duration(milliseconds: 100));
            notificationService.setCurrentChat(null);
          } catch (e) {
            print('[NOTIFICATION] Error handling reply: $e');
          }
        };
        
        // Initialize FCM and register token (только на мобильных платформах и web)
        final shouldInitFcm = kIsWeb || Platform.isAndroid || Platform.isIOS;
        if (shouldInitFcm) {
          try {
            final fcmService = ref.read(fcmServiceProvider);
            await fcmService.initialize();
            
            // Setup FCM navigation callback
            fcmService.onMessageTap = (chatId) async {
              // #region agent log - Hypothesis A: Track push tap navigation flow
              print('[PUSH_NAV] HYP_A1: Push notification tapped for chat: $chatId, timestamp: ${DateTime.now().toIso8601String()}');
              // #endregion
              
              try {
                // #region agent log - Hypothesis C: Check SignalR status before navigation
                final signalRState = ref.read(signalRConnectionProvider);
                print('[PUSH_NAV] HYP_C1: SignalR connected: ${signalRState.isConnected}');
                // #endregion
                
                // STEP 1: Refresh chats list to ensure chat exists
                print('[FCM] Refreshing chats list...');
                // #region agent log - Hypothesis A: Track chats load timing
                final chatsLoadStart = DateTime.now();
                // #endregion
                await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                // #region agent log - Hypothesis A
                final chatsLoadDuration = DateTime.now().difference(chatsLoadStart).inMilliseconds;
                print('[PUSH_NAV] HYP_A2: Chats loaded in ${chatsLoadDuration}ms');
                // #endregion
                
                // STEP 2: Force refresh messages for this chat to show new message
                print('[FCM] Loading messages for chat $chatId...');
                // #region agent log - Hypothesis A/E: Track messages load timing and result
                final messagesLoadStart = DateTime.now();
                // #endregion
                await ref.read(messagesProvider(chatId).notifier).loadMessages(forceRefresh: true);
                // #region agent log - Hypothesis A/E
                final messagesLoadDuration = DateTime.now().difference(messagesLoadStart).inMilliseconds;
                final messagesState = ref.read(messagesProvider(chatId));
                print('[PUSH_NAV] HYP_A3: Messages loaded in ${messagesLoadDuration}ms, count: ${messagesState.messages.length}, isLoading: ${messagesState.isLoading}, error: ${messagesState.error}');
                // #endregion
                
                // STEP 3: Wait a bit to ensure messages are loaded
                await Future.delayed(const Duration(milliseconds: 300));
                
                // #region agent log - Hypothesis A: Check messages after delay
                final messagesStateAfterDelay = ref.read(messagesProvider(chatId));
                print('[PUSH_NAV] HYP_A4: After delay - messages count: ${messagesStateAfterDelay.messages.length}, isLoading: ${messagesStateAfterDelay.isLoading}');
                // #endregion
                
                // STEP 4: Navigate to chat screen
                print('[FCM] Navigating to chat screen...');
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                  ),
                  (route) => route.isFirst, // Keep only the main screen in stack
                );
                
                // #region agent log - Hypothesis A
                print('[PUSH_NAV] HYP_A5: Navigation completed');
                // #endregion
              } catch (e) {
                // #region agent log - Hypothesis A
                print('[PUSH_NAV] HYP_A_ERROR: Error handling notification tap: $e');
                // #endregion
                // Try to navigate anyway
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                  ),
                );
              }
            };

            // Setup FCM message received callback for immediate message fetch
            fcmService.onMessageReceived = (messageId, chatId) async {
              print('[FCM] Message received notification for message $messageId in chat $chatId');
              
              try {
                // Check if we have the message in cache first
                final cache = ref.read(messageCacheProvider);
                final cachedMessage = cache.get(messageId);
                
                if (cachedMessage != null) {
                  print('[FCM] Message already in cache, no fetch needed');
                  return;
                }
                
                print('[FCM] Message not in cache, fetching from API...');
                
                // Fetch message from API using new method
                final messageRepo = ref.read(messageRepositoryProvider);
                final message = await messageRepo.getMessageById(messageId);
                
                print('[FCM] Message fetched successfully: ${message.id}');
                
                // Update the messages provider to include this message
                final messagesNotifier = ref.read(messagesProvider(chatId).notifier);
                // The message will be automatically added via SignalR or incremental sync
                // Just trigger a sync to be safe
                messagesNotifier.loadMessages(forceRefresh: true);
                
                print('[FCM] Message fetch completed');
              } catch (e) {
                print('[FCM] Failed to fetch message on push notification: $e');
              }
            };

            fcmService.onMessageReply = (chatId, text) async {
              print('[FCM] Reply received for chat $chatId: $text');
              try {
                if (text.trim().isEmpty) {
                  print('[FCM] Empty reply text, ignoring');
                  return;
                }
                
                await ref.read(messagesProvider(chatId).notifier).sendMessage(text);
                print('[FCM] Reply sent successfully');
                
                // Clear the notification after reply
                fcmService.setCurrentChat(chatId);
                fcmService.setCurrentChat(null);
              } catch (e) {
                print('[FCM] Error handling reply: $e');
              }
            };
            
            // Register token immediately after initialization
            final authRepo = ref.read(authRepositoryProvider);
            final token = await authRepo.getStoredToken();
            
            if (token != null) {
              await fcmService.registerToken(token);
            }
          } catch (e) {
            print('FCM initialization failed: $e');
          }
        } else {
          print('FCM skipped on desktop platform - using local notifications only');
        }
      });
    }

    // Показываем экран загрузки пока проверяется auth
    if (authState.isLoading) {
      return MaterialApp(
        title: 'Депеша',
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Депеша',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: authState.isAuthenticated
          ? const MainScreen()
          : const AuthScreen(),
    );
  }
}
