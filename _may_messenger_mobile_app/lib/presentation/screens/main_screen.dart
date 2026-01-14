import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/user_status_sync_service.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/global_audio_mini_player.dart';
import '../../core/services/global_audio_service.dart';
import '../../data/services/battery_optimization_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'create_group_screen.dart';
import 'new_chat_screen.dart';
import 'search_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _isFirstBuild = true;
  bool _wasOffline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    
    // Загружаем чаты и контакты после того, как виджет смонтирован
    // В этот момент токен уже точно восстановлен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load contacts mapping for displaying names from phone book
        ref.read(contactsNamesProvider.notifier).loadContactsMapping();
        // Load chats
        ref.read(chatsProvider.notifier).loadChats();
        
        // Load user statuses after chats are loaded
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(userStatusSyncServiceProvider).loadInitialStatuses();
            
            // Start periodic sync as fallback
            ref.read(userStatusSyncServiceProvider).startPeriodicSync();
          }
        });
        
        // Check battery optimization (show dialog if optimization is enabled)
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
            final batteryService = ref.read(batteryOptimizationServiceProvider);
            final isDisabled = await batteryService.isBatteryOptimizationDisabled();
            if (!isDisabled) {
              batteryService.showOptimizationDialog(context);
            }
          }
        });
        
        // Listen for connectivity changes to auto-refresh when back online
        _setupConnectivityListener();
      }
    });
  }
  
  void _setupConnectivityListener() {
    final connectivityService = ref.read(connectivityServiceProvider);
    _connectivitySubscription = connectivityService.connectionStream.listen((isConnected) {
      if (isConnected && _wasOffline && mounted) {
        print('[MainScreen] Network restored, refreshing chats...');
        // Auto-refresh when connection is restored after being offline
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
          }
        });
      }
      _wasOffline = !isConnected;
    });
    
    // Set initial offline state
    _wasOffline = !connectivityService.isConnected;
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    ref.read(userStatusSyncServiceProvider).stopPeriodicSync();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Skip first build (already handled in initState)
    if (_isFirstBuild) {
      _isFirstBuild = false;
      return;
    }
    
    // Refresh chats when returning to this screen
    print('[MainScreen] didChangeDependencies - refreshing chats');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Депеша'),
        actions: [
          const ConnectionStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
        // Thin sync indicator under AppBar - non-intrusive
        bottom: chatsState.isSyncing ? PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          ),
        ) : null,
      ),
      body: Column(
        children: [
          // Mini player for audio playback (shown when audio is playing)
          GlobalAudioMiniPlayer(
            onTap: () => _navigateToAudioChat(ref.read(globalAudioServiceProvider)),
          ),
          // Chat list
          Expanded(
            child: _buildChatList(chatsState.chats, chatsState.isLoading, chatsState.error),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateChatOptions(context),
        tooltip: 'Создать чат',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        child: const Icon(Icons.edit),
      ),
    );
  }
  
  void _navigateToAudioChat(AudioPlaybackState playbackState) {
    if (playbackState.chatId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: playbackState.chatId!),
        ),
      );
    }
  }
  
  void _showCreateChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Личный чат'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NewChatScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Создать группу'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(List chats, bool isLoading, String? error) {
    final chatsState = ref.watch(chatsProvider);
    final isOfflineMode = chatsState.isOfflineMode;
    final syncError = chatsState.syncError;
    
    if (isLoading && chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // If there's a blocking error and no chats at all
    if (error != null && chats.isEmpty) {
      // Check if it's a server error (500) or network error
      final isServerError = error.contains('500') || error.contains('сервер');
      final isNetworkError = error.contains('подключения') || error.contains('интернет') || error.contains('timeout');
      
      return RefreshIndicator(
        onRefresh: () => ref.read(chatsProvider.notifier).loadChats(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isServerError ? Icons.cloud_off : (isNetworkError ? Icons.wifi_off : Icons.chat_bubble_outline),
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isServerError 
                          ? 'Сервер временно недоступен'
                          : (isNetworkError ? 'Нет подключения к интернету' : 'Не удалось загрузить чаты'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isServerError
                          ? 'Попробуйте обновить через несколько минут'
                          : (isNetworkError ? 'Проверьте подключение и попробуйте снова' : 'Потяните вниз для обновления'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Обновить'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (chats.isEmpty) {
      return const Center(
        child: Text('Нет чатов'),
      );
    }

    // Show chats with offline status banner (syncing indicator moved to AppBar)
    return Column(
      children: [
        // Offline mode banner (with sync error if any)
        if (isOfflineMode || syncError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncError ?? 'Работа в офлайн режиме',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  onPressed: () => ref.read(chatsProvider.notifier).loadChats(forceRefresh: true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(chatsProvider.notifier).loadChats(forceRefresh: true),
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                
                return ChatListItem(
                  chat: chat,
                  onTap: () async {
                    // Navigate to chat screen
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chatId: chat.id),
                      ),
                    );
                    
                    // CRITICAL: Refresh chats from server when returning from chat
                    // This ensures unread counts and last messages are accurate
                    if (mounted) {
                      await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                    }
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


