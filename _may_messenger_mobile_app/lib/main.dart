import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'core/themes/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/avatar_cache_service.dart';
import 'core/services/background_audio_service.dart';
import 'core/services/share_receive_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/signalr_provider.dart';
import 'presentation/providers/chats_provider.dart';
import 'presentation/providers/messages_provider.dart';
import 'presentation/providers/user_status_sync_service.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/share_target_screen.dart';

// Global navigator key for navigation from FCM
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Pending chat navigation when app was launched from terminated state
String? _pendingChatNavigation;

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
  
  print('[FCM_BG] Parsed: title=$title, body=$body, chatId=$chatId');
  
  if (chatId == null || chatId.isEmpty) {
    print('[FCM_BG] No chatId in message, skipping notification');
    return;
  }
  
  // Initialize local notifications for background handler
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  
  await _localNotifications.initialize(initSettings);
  
  // Generate consistent notification ID from chatId
  // Using absolute value to avoid negative IDs
  final notificationId = chatId.hashCode.abs();
  
  // Show local notification with grouping support
  // Using tag ensures only one notification per chat (replaces previous)
  try {
    final androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      groupKey: 'chat_$chatId', // Group by specific chat
      tag: 'chat_$chatId', // Tag ensures replacement of same-chat notifications
      onlyAlertOnce: false, // Alert on each new message
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      notificationId, // Consistent ID per chat
      title,
      body,
      notificationDetails,
      payload: chatId,
    );
    
    print('[FCM_BG] Local notification shown for chat $chatId with id $notificationId');
  } catch (e) {
    print('[FCM_BG] Error showing notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize avatar cache for local storage
  await avatarCacheService.init();
  
  // Initialize date formatting for Russian locale
  await initializeDateFormatting('ru', null);
  
  // Initialize Background Audio Service
  MayMessengerAudioHandler? audioHandler;
  try {
    final audioPlayer = AudioPlayer();
    audioHandler = await AudioService.init(
      builder: () => MayMessengerAudioHandler(audioPlayer),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'ru.rare-books.messenger.audio',
        androidNotificationChannelName: 'Воспроизведение аудиосообщений',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
      ),
    );
    print('[AudioService] Background audio service initialized');
  } catch (e) {
    print('[AudioService] Failed to initialize: $e (audio playback may not work in background)');
  }
  
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
    ProviderScope(
      overrides: [
        // Override audioHandlerProvider with initialized handler
        if (audioHandler != null)
          audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MyApp(),
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
  ShareReceiveService? _shareReceiveService;
  SharedContent? _pendingShare;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize share receive service
    _initShareReceiveService();
  }
  
  /// Initialize the share receive service to handle incoming shares
  void _initShareReceiveService() {
    _shareReceiveService = ref.read(shareReceiveServiceProvider);
    
    // Initialize and listen for shares
    _shareReceiveService?.init(
      onReceive: (SharedContent content) {
        print('[SHARE] Received share while app is running: ${content.type}');
        _handleIncomingShare(content);
      },
    );
    
    // Check for initial share (app launched via share)
    _checkInitialShare();
  }
  
  /// Check if app was launched with shared content
  Future<void> _checkInitialShare() async {
    try {
      final content = await _shareReceiveService?.getInitialSharedContent();
      if (content != null && !content.isEmpty) {
        print('[SHARE] App launched with shared content: ${content.type}');
        _pendingShare = content;
        // Handle will be triggered after auth check
      }
    } catch (e) {
      print('[SHARE] Error checking initial share: $e');
    }
  }
  
  /// Handle incoming shared content
  void _handleIncomingShare(SharedContent content) {
    final authState = ref.read(authStateProvider);
    
    if (!authState.isAuthenticated) {
      print('[SHARE] User not authenticated, storing pending share');
      _pendingShare = content;
      return;
    }
    
    // Navigate to share target screen
    _navigateToShareTarget(content);
  }
  
  /// Navigate to the share target selection screen
  void _navigateToShareTarget(SharedContent content) {
    Future.microtask(() {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ShareTargetScreen(sharedContent: content),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareReceiveService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('[LIFECYCLE] App state changed to: $state');
    
    final authState = ref.read(authStateProvider);
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _lastPausedAt = DateTime.now();
      print('[LIFECYCLE] App $state at $_lastPausedAt - marking user as offline');
      
      // CRITICAL: Mark user as offline when app is paused/minimized/closed
      if (authState.isAuthenticated) {
        try {
          final apiDataSource = ref.read(apiDataSourceProvider);
          apiDataSource.goOffline();
        } catch (e) {
          print('[LIFECYCLE] Failed to mark user offline: $e');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (authState.isAuthenticated) {
        final pauseDuration = _lastPausedAt != null 
            ? DateTime.now().difference(_lastPausedAt!)
            : Duration.zero;
        
        print('[LIFECYCLE] App resumed after ${pauseDuration.inSeconds}s pause');
        
        // CRITICAL: Mark user as online when app is resumed
        try {
          final apiDataSource = ref.read(apiDataSourceProvider);
          apiDataSource.goOnline();
        } catch (e) {
          print('[LIFECYCLE] Failed to mark user online: $e');
        }
        
        // Show reconnecting banner only for long pauses (> 10 seconds)
        if (pauseDuration.inSeconds > 10) {
          print('[LIFECYCLE] Long pause detected (> 10s), showing reconnecting banner');
          ref.read(signalRConnectionProvider.notifier).setReconnecting(true);
          _performResumeSync();
        } else {
          // Short pause, silent reconnect without banner
          print('[LIFECYCLE] Short pause (<= 10s), performing silent reconnect');
          final signalRState = ref.read(signalRConnectionProvider);
          
          if (!signalRState.isConnected) {
            print('[LIFECYCLE] SignalR disconnected - attempting silent reconnect');
            ref.read(signalRConnectionProvider.notifier).silentReconnect();
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
      
      // 4. Refresh user statuses
      print('[LIFECYCLE] Step 4: Refreshing user statuses');
      try {
        await ref.read(userStatusSyncServiceProvider).loadInitialStatuses();
        print('[LIFECYCLE] User statuses refreshed');
      } catch (e) {
        print('[LIFECYCLE] Failed to refresh user statuses: $e');
      }
      
      print('[LIFECYCLE] Resume sync completed successfully');
      
      // Clear reconnecting banner
      ref.read(signalRConnectionProvider.notifier).setReconnecting(false);
    } catch (e) {
      print('[LIFECYCLE] Error during resume sync: $e');
      // Clear reconnecting banner even on error
      ref.read(signalRConnectionProvider.notifier).setReconnecting(false);
      // Non-fatal, app will continue to work
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    // Handle pending share after authentication
    if (authState.isAuthenticated && _pendingShare != null) {
      final share = _pendingShare;
      _pendingShare = null; // Clear to avoid re-triggering
      Future.microtask(() {
        if (share != null) {
          _navigateToShareTarget(share);
        }
      });
    }
    
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
            
            // CRITICAL: Mark user as online immediately after token restore
            // This ensures user appears online instantly when app starts
            try {
              await apiDataSource.goOnline();
              print('[LIFECYCLE] User marked as online on app start');
            } catch (e) {
              print('[LIFECYCLE] Failed to mark user online on start: $e');
            }
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
        // SIMPLIFIED: Don't preload messages here - ChatScreen handles its own loading
        notificationService.onNotificationTap = (chatId, messageId) async {
          print('[NOTIFICATION] Local notification tapped for chat: $chatId, message: $messageId');
          
          // IMPORTANT: Validate chatId before navigating
          if (chatId.isEmpty) {
            print('[NOTIFICATION] Invalid chatId (empty), aborting navigation');
            return;
          }
          
          try {
            // STEP 1: Force refresh chats list first to ensure chat exists
            print('[NOTIFICATION] Refreshing chats list...');
            await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
            
            // STEP 2: Verify chat exists
            final chatsState = ref.read(chatsProvider);
            final chatExists = chatsState.chats.any((chat) => chat.id == chatId);
            
            if (!chatExists) {
              print('[NOTIFICATION] Chat $chatId not found in chats list');
            }
            
            // STEP 3: Navigate to chat - ChatScreen will handle message loading
            print('[NOTIFICATION] Navigating to chat screen: $chatId');
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  highlightMessageId: messageId,
                ),
              ),
              (route) => route.isFirst,
            );
            
            print('[NOTIFICATION] Navigation completed');
          } catch (e) {
            print('[NOTIFICATION] Error handling notification tap: $e');
            // Navigate anyway on error if chatId is valid
            if (chatId.isNotEmpty) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    highlightMessageId: messageId,
                  ),
                ),
              );
            }
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
            // SIMPLIFIED: Don't preload messages here - ChatScreen handles its own loading
            // This prevents race conditions when multiple loads compete
            fcmService.onMessageTap = (chatId) async {
              print('[PUSH_NAV] Push notification tapped for chat: $chatId');
              
              try {
                // IMPORTANT: Validate chatId before navigating
                if (chatId.isEmpty) {
                  print('[PUSH_NAV] Invalid chatId (empty), aborting navigation');
                  return;
                }
                
                // Clear notifications for this chat
                await fcmService.clearChatNotifications(chatId);
                
                // CRITICAL: Ensure token is restored before navigating
                // This prevents 401 errors when ChatScreen tries to load messages
                final authRepo = ref.read(authRepositoryProvider);
                final apiDataSource = ref.read(apiDataSourceProvider);
                final token = await authRepo.getStoredToken();
                
                if (token != null) {
                  apiDataSource.setToken(token);
                  print('[PUSH_NAV] Token restored: ${token.substring(0, 20)}...');
                } else {
                  print('[PUSH_NAV] WARNING: No token found, navigation may fail');
                }
                
                // Wait for navigator to be ready (important when app was terminated)
                await Future.delayed(const Duration(milliseconds: 100));
                
                final navigator = navigatorKey.currentState;
                if (navigator == null) {
                  print('[PUSH_NAV] Navigator not ready, waiting...');
                  // Store chatId for later navigation when app is ready
                  _pendingChatNavigation = chatId;
                  return;
                }
                
                // Background: Try to ensure SignalR is connected (don't block navigation)
                final signalRState = ref.read(signalRConnectionProvider);
                print('[PUSH_NAV] SignalR connected: ${signalRState.isConnected}');
                
                if (!signalRState.isConnected) {
                  // Try silent reconnect in background
                  print('[PUSH_NAV] SignalR not connected, attempting reconnect in background...');
                  ref.read(signalRConnectionProvider.notifier).silentReconnect();
                }
                
                // Don't wait for chats list - navigate immediately for better UX
                // ChatScreen will load its own data
                print('[PUSH_NAV] Navigating to chat screen: $chatId');
                
                // Use pushNamedAndRemoveUntil pattern for reliable navigation
                // First, ensure we're on the main screen, then push chat
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                    settings: RouteSettings(name: '/chat/$chatId'),
                  ),
                  (route) => route.isFirst || route.settings.name == '/main',
                );
                
                print('[PUSH_NAV] Navigation to chat $chatId completed');
                
                // Refresh chats list in background
                ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                
              } catch (e, stack) {
                print('[PUSH_NAV] Error handling notification tap: $e');
                print('[PUSH_NAV] Stack: $stack');
                // Navigate anyway on error - ChatScreen will handle errors
                if (chatId.isNotEmpty) {
                  try {
                    navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chatId),
                      ),
                    );
                  } catch (navError) {
                    print('[PUSH_NAV] Fallback navigation also failed: $navError');
                  }
                }
              }
            };

            // Setup FCM message received callback for immediate message fetch
            // NOTE: This is called when FCM push is received while app is in foreground
            // The message will be displayed when user opens the chat
            // Do NOT call markMessagesAsRead here - that should only happen when user views the chat
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
                
                // Only add message to provider if the chat is currently open
                // This prevents unnecessary provider initialization
                // If chat is not open, message will be loaded when user opens it
                try {
                  // Use read to check if provider exists without forcing creation
                  final messagesNotifier = ref.read(messagesProvider(chatId).notifier);
                  await messagesNotifier.addMessage(message);
                  print('[FCM] Message added to active chat provider');
                } catch (e) {
                  // Provider not initialized - chat not open, that's fine
                  // Message will be loaded when user opens the chat
                  print('[FCM] Chat not open, message will load when chat is opened');
                }
                
                print('[FCM] Message fetch completed');
              } catch (e) {
                print('[FCM] Failed to fetch message on push notification: $e');
              }
            };

            // Reply action removed - not reliable enough
            
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

    // Watch theme state
    final themeState = ref.watch(themeProvider);
    
    // Показываем экран загрузки пока проверяется auth
    if (authState.isLoading) {
      return MaterialApp(
        title: 'Депеша',
        theme: themeState.lightTheme,
        darkTheme: themeState.darkTheme,
        themeMode: themeState.flutterThemeMode,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    // Handle pending chat navigation from push notification
    if (_pendingChatNavigation != null && authState.isAuthenticated) {
      final pendingChatId = _pendingChatNavigation;
      _pendingChatNavigation = null;
      
      // Schedule navigation after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (pendingChatId != null && navigatorKey.currentState != null) {
          print('[PUSH_NAV] Processing pending navigation to chat: $pendingChatId');
          
          // CRITICAL: Ensure token is set before navigating
          try {
            final authRepo = ref.read(authRepositoryProvider);
            final apiDataSource = ref.read(apiDataSourceProvider);
            final token = await authRepo.getStoredToken();
            if (token != null) {
              apiDataSource.setToken(token);
              print('[PUSH_NAV] Token restored for pending navigation');
            }
          } catch (e) {
            print('[PUSH_NAV] Error restoring token: $e');
          }
          
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(chatId: pendingChatId),
              settings: RouteSettings(name: '/chat/$pendingChatId'),
            ),
          );
        }
      });
    }
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Депеша',
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.flutterThemeMode,
      debugShowCheckedModeBanner: false,
      home: authState.isAuthenticated
          ? const MainScreen()
          : const AuthScreen(),
    );
  }
}
