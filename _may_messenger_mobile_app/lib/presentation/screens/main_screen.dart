import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chats_provider.dart';
import '../widgets/chat_list_item.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'create_chat_screen.dart';

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
        title: const Text('May Messenger'),
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
            Tab(text: 'Группы', icon: Icon(Icons.group)),
            Tab(text: 'Личные', icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Groups Tab
          _buildChatList(chatsState.groupChats, chatsState.isLoading, chatsState.error),
          // Private Tab
          _buildChatList(chatsState.privateChats, chatsState.isLoading, chatsState.error),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Определяем тип чата по текущей вкладке
          // 0 = Группы, 1 = Личные
          final isGroupChat = _tabController.index == 0;
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateChatScreen(
                initialIsGroupChat: isGroupChat,
              ),
            ),
          );
        },
        tooltip: _tabController.index == 0 
            ? 'Создать группу' 
            : 'Создать личный чат',
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


