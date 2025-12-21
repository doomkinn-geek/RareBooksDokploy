import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/connection_status_banner.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'create_group_screen.dart';
import 'new_chat_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Обновляем UI при переключении вкладки (для изменения tooltip FAB)
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // Загружаем чаты и контакты после того, как виджет смонтирован
    // В этот момент токен уже точно восстановлен
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load contacts mapping for displaying names from phone book
        ref.read(contactsNamesProvider.notifier).loadContactsMapping();
        // Load chats
        ref.read(chatsProvider.notifier).loadChats();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Депеша'),
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Личные', icon: Icon(Icons.person)),
            Tab(text: 'Группы', icon: Icon(Icons.group)),
          ],
        ),
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Private Tab
                _buildChatList(chatsState.privateChats, chatsState.isLoading, chatsState.error),
                // Groups Tab
                _buildChatList(chatsState.groupChats, chatsState.isLoading, chatsState.error),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Определяем тип чата по текущей вкладке
          // 0 = Личные, 1 = Группы
          final isGroupChat = _tabController.index == 1;
          
          if (isGroupChat) {
            // Для групп используем новый экран с контактами
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateGroupScreen(),
              ),
            );
          } else {
            // Для личных чатов используем новый экран с контактами
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NewChatScreen(),
              ),
            );
          }
        },
        tooltip: _tabController.index == 0 
            ? 'Создать личный чат' 
            : 'Создать группу',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChatList(List chats, bool isLoading, String? error) {
    if (isLoading && chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (chats.isEmpty) {
      return const Center(
        child: Text('Нет чатов'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(chatsProvider.notifier).loadChats(forceRefresh: true),
      child: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          
          return ChatListItem(
            chat: chat,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(chatId: chat.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


