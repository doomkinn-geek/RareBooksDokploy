import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
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
      }
    });
  }
  
  @override
  void dispose() {
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
    final isSyncing = chatsState.isSyncing;
    final syncError = chatsState.syncError;
    
    if (isLoading && chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // If there's a blocking error and no chats at all
    if (error != null && chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Не удалось загрузить чаты',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
                },
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (chats.isEmpty) {
      return const Center(
        child: Text('Нет чатов'),
      );
    }

    // Show chats with offline/sync status banner
    return Column(
      children: [
        // Syncing indicator (non-blocking)
        if (isSyncing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.shade100,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Синхронизация...',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
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


