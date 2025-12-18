import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        notificationService.onNotificationTap = (chatId) async {
          print('[NOTIFICATION] Local notification tapped for chat: $chatId');
          
          try {
            // STEP 1: Refresh chats list to ensure chat exists
            print('[NOTIFICATION] Refreshing chats list...');
            await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
            
            // STEP 2: Force refresh messages for this chat to show new message
            print('[NOTIFICATION] Loading messages for chat $chatId...');
            await ref.read(messagesProvider(chatId).notifier).loadMessages(forceRefresh: true);
            
            // STEP 3: Wait a bit to ensure messages are loaded
            await Future.delayed(const Duration(milliseconds: 300));
            
            // STEP 4: Navigate to chat screen
            print('[NOTIFICATION] Navigating to chat screen...');
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatId: chatId),
              ),
              (route) => route.isFirst, // Keep only the main screen in stack
            );
            
            print('[NOTIFICATION] Navigation completed');
          } catch (e) {
            print('[NOTIFICATION] Error handling notification tap: $e');
            // Try to navigate anyway
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatId: chatId),
              ),
            );
          }
        };

        notificationService.onNotificationReply = (chatId, text) async {
          print('[NOTIFICATION] Reply received for chat $chatId: $text');
          try {
             await ref.read(messagesProvider(chatId).notifier).sendMessage(text);
             // Optionally navigate to chat to show the sent message
             navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatId: chatId),
              ),
            );
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
              print('[FCM] Push notification tapped for chat: $chatId');
              
              try {
                // STEP 1: Refresh chats list to ensure chat exists
                print('[FCM] Refreshing chats list...');
                await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                
                // STEP 2: Force refresh messages for this chat to show new message
                print('[FCM] Loading messages for chat $chatId...');
                await ref.read(messagesProvider(chatId).notifier).loadMessages(forceRefresh: true);
                
                // STEP 3: Wait a bit to ensure messages are loaded
                await Future.delayed(const Duration(milliseconds: 300));
                
                // STEP 4: Navigate to chat screen
                print('[FCM] Navigating to chat screen...');
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                  ),
                  (route) => route.isFirst, // Keep only the main screen in stack
                );
                
                print('[FCM] Navigation completed');
              } catch (e) {
                print('[FCM] Error handling notification tap: $e');
                // Try to navigate anyway
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                  ),
                );
              }
            };

            fcmService.onMessageReply = (chatId, text) async {
              print('[FCM] Reply received for chat $chatId: $text');
              try {
                await ref.read(messagesProvider(chatId).notifier).sendMessage(text);
                // Optionally navigate to chat
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId),
                  ),
                );
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
        title: 'May Messenger',
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
      title: 'May Messenger',
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
