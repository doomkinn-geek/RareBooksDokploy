import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/utils/error_formatter.dart';
import '../../data/models/chat_model.dart';
import 'chat_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Preload search data for instant results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).preload();
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    // Clear search results when leaving
    ref.read(searchProvider.notifier).clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: const InputDecoration(
            hintText: 'Поиск чатов, контактов и сообщений...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.grey),
          onChanged: (query) {
            ref.read(searchProvider.notifier).search(query);
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: _buildBody(searchState),
    );
  }

  Widget _buildBody(SearchState state) {
    if (state.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Начните вводить для поиска',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Чаты • Контакты • Сообщения',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_bolt, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Локальный поиск',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text(
              'Поиск...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state.error != null && state.error != 'Введите минимум 2 символа') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (state.error == 'Введите минимум 2 символа') {
      return Center(
        child: Text(
          state.error!,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    final hasChats = state.chatResults.isNotEmpty;
    final hasUsers = state.userResults.isNotEmpty;
    final hasMessages = state.messageResults.isNotEmpty;

    if (!hasChats && !hasUsers && !hasMessages) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить запрос',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final totalCount = state.chatResults.length + 
                       state.userResults.length + 
                       state.messageResults.length;

    return Column(
      children: [
        // Search stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text(
                'Найдено: $totalCount',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (state.searchTimeMs != null)
                Row(
                  children: [
                    Icon(Icons.flash_on, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${state.searchTimeMs}мс',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              // Chats and groups section
              if (hasChats) ...[
                _buildSectionHeader(
                  context,
                  'Чаты',
                  state.chatResults.length,
                  Icons.chat_bubble_outline,
                ),
                ...state.chatResults.map((chat) => _buildChatTile(context, chat)),
                if (hasUsers || hasMessages) const Divider(height: 1),
              ],
              // Contacts section
              if (hasUsers) ...[
                _buildSectionHeader(
                  context,
                  'Контакты',
                  state.userResults.length,
                  Icons.person_outline,
                ),
                ...state.userResults.map((user) => _buildUserTile(context, user)),
                if (hasMessages) const Divider(height: 1),
              ],
              // Messages section
              if (hasMessages) ...[
                _buildSectionHeader(
                  context,
                  'Сообщения',
                  state.messageResults.length,
                  Icons.message_outlined,
                ),
                ...state.messageResults.map((result) => _buildMessageTile(context, result)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, Chat chat) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: chat.type == ChatType.group
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          chat.type == ChatType.group ? Icons.group : Icons.person,
          color: chat.type == ChatType.group
              ? Theme.of(context).colorScheme.onTertiaryContainer
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        chat.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        chat.type == ChatType.group ? 'Группа' : 'Личный чат',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chat.id),
          ),
        );
      },
    );
  }

  Widget _buildUserTile(BuildContext context, dynamic user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        user.phoneNumber,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      onTap: () async {
        // Create or get direct chat with this user
        try {
          final chatRepository = ref.read(chatRepositoryProvider);
          final chat = await chatRepository.createOrGetDirectChat(user.id);
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(chatId: chat.id),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: ${formatUserFriendlyError(e)}')),
            );
          }
        }
      },
    );
  }

  Widget _buildMessageTile(BuildContext context, dynamic result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          Icons.chat_bubble_outline,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          size: 18,
        ),
      ),
      title: Text(
        result.chatTitle,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.messageContent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            result.senderName,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: result.chatId,
              highlightMessageId: result.messageId,
            ),
          ),
        );
      },
    );
  }
}
