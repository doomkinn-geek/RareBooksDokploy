import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/themes/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/signalr_provider.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize Firebase (optional - может потребовать настройки google-services.json)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization failed (may be not configured): $e');
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
      ref.read(signalRConnectionProvider);
      
      // Initialize notification service
      Future.microtask(() async {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.initialize();
        
        // Initialize FCM and register token
        try {
          final fcmService = ref.read(fcmServiceProvider);
          await fcmService.initialize();
          
          // Register token immediately after initialization
          final authRepo = ref.read(authRepositoryProvider);
          final token = await authRepo.getStoredToken();
          
          if (token != null) {
            await fcmService.registerToken(token);
          }
        } catch (e) {
          print('FCM initialization failed: $e');
        }
      });
    }

    return MaterialApp(
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
