import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'l10n/app_localizations.dart';

import 'config/theme.dart';
import 'services/services.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage service
  final storageService = StorageService();
  await storageService.init();
  
  // Create API service
  final apiService = ApiService(storageService: storageService);
  
  // Create auth service
  final authService = AuthService(
    apiService: apiService,
    storageService: storageService,
  );
  
  runApp(RareBooksApp(
    storageService: storageService,
    apiService: apiService,
    authService: authService,
  ));
}

/// Main application widget
class RareBooksApp extends StatelessWidget {
  final StorageService storageService;
  final ApiService apiService;
  final AuthService authService;
  
  const RareBooksApp({
    super.key,
    required this.storageService,
    required this.apiService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Language provider
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(storageService: storageService),
        ),
        
        // Auth provider
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService: authService),
        ),
        
        // Books provider
        ChangeNotifierProvider(
          create: (_) => BooksProvider(apiService: apiService),
        ),
        
        // Collection provider
        ChangeNotifierProvider(
          create: (_) => CollectionProvider(apiService: apiService),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return _AppInitializer(
            routerConfig: _createRouter(context),
            languageProvider: languageProvider,
          );
        },
      ),
    );
  }
  
  GoRouter _createRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        // Don't call initialize() here - it causes setState during build
        // Initialize will be called in _AppInitializer widget
        return null;
      },
      routes: [
        // Main shell with bottom navigation
        ShellRoute(
          builder: (context, state, child) {
            return MainShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
            GoRoute(
              path: '/collection',
              builder: (context, state) => const CollectionScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        
        // Auth routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        
        // Search results
        GoRoute(
          path: '/search/title/:query',
          builder: (context, state) {
            final query = state.pathParameters['query'] ?? '';
            final exact = state.uri.queryParameters['exact'] == 'true';
            return SearchResultsScreen(
              searchType: SearchType.title,
              query: query,
              exactMatch: exact,
            );
          },
        ),
        GoRoute(
          path: '/search/description/:query',
          builder: (context, state) {
            final query = state.pathParameters['query'] ?? '';
            final exact = state.uri.queryParameters['exact'] == 'true';
            return SearchResultsScreen(
              searchType: SearchType.description,
              query: query,
              exactMatch: exact,
            );
          },
        ),
        GoRoute(
          path: '/search/price/:min/:max',
          builder: (context, state) {
            final min = double.tryParse(state.pathParameters['min'] ?? '0') ?? 0;
            final max = double.tryParse(state.pathParameters['max'] ?? '0') ?? 0;
            return SearchResultsScreen(
              searchType: SearchType.priceRange,
              minPrice: min,
              maxPrice: max,
            );
          },
        ),
        GoRoute(
          path: '/search/category/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            return SearchResultsScreen(
              searchType: SearchType.category,
              categoryId: id,
            );
          },
        ),
        GoRoute(
          path: '/search/seller/:name',
          builder: (context, state) {
            final name = state.pathParameters['name'] ?? '';
            return SearchResultsScreen(
              searchType: SearchType.seller,
              query: name,
            );
          },
        ),
        
        // Book detail
        GoRoute(
          path: '/book/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            return BookDetailScreen(bookId: id);
          },
        ),
        
        // Collection book detail
        GoRoute(
          path: '/collection/book/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            return CollectionBookDetailScreen(bookId: id);
          },
        ),
        
        // Add collection book
        GoRoute(
          path: '/collection/add',
          builder: (context, state) => const AddCollectionBookScreen(),
        ),
        
        // Subscription
        GoRoute(
          path: '/subscription',
          builder: (context, state) => const SubscriptionScreen(),
        ),
        
        // Notifications
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        
        // Contacts
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const ContactsScreen(),
        ),
        
        // Terms of Service
        GoRoute(
          path: '/terms',
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
        
        // Telegram Bot Guide
        GoRoute(
          path: '/telegram-guide',
          builder: (context, state) => const TelegramGuideScreen(),
        ),
        
        // Collection book matches
        GoRoute(
          path: '/collection/:id/matches',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
            final title = state.uri.queryParameters['title'];
            return CollectionMatchesScreen(bookId: id, bookTitle: title);
          },
        ),
      ],
    );
  }
}

/// Widget to initialize auth after build phase
class _AppInitializer extends StatefulWidget {
  final GoRouter routerConfig;
  final LanguageProvider languageProvider;
  
  const _AppInitializer({
    required this.routerConfig,
    required this.languageProvider,
  });
  
  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize auth after first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isInitialized) {
        authProvider.initialize();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rare Books',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      
      // Localization
      locale: widget.languageProvider.locale,
      supportedLocales: LanguageProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Routing
      routerConfig: widget.routerConfig,
    );
  }
}

/// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final location = GoRouterState.of(context).uri.path;
    
    // Determine selected index based on current route
    int selectedIndex = 0;
    if (location == '/categories') {
      selectedIndex = 1;
    } else if (location == '/favorites') {
      selectedIndex = 2;
    } else if (location == '/collection') {
      selectedIndex = 3;
    } else if (location == '/profile') {
      selectedIndex = 4;
    }
    
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/categories');
              break;
            case 2:
              if (authProvider.isAuthenticated) {
                context.go('/favorites');
              } else {
                context.push('/login');
              }
              break;
            case 3:
              if (authProvider.hasCollectionAccess) {
                context.go('/collection');
              } else if (authProvider.isAuthenticated) {
                context.push('/subscription');
              } else {
                context.push('/login');
              }
              break;
            case 4:
              if (authProvider.isAuthenticated) {
                context.go('/profile');
              } else {
                context.push('/login');
              }
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.category),
            label: AppLocalizations.of(context)!.catalog,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: AppLocalizations.of(context)!.favorites,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.collections_bookmark),
            label: AppLocalizations.of(context)!.collection,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppLocalizations.of(context)!.profile,
          ),
        ],
      ),
    );
  }
}
