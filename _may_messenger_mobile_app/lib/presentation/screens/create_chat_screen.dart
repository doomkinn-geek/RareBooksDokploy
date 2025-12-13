import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_provider.dart';
import 'chat_screen.dart';

final usersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final apiDataSource = ref.read(apiDataSourceProvider);
  return await apiDataSource.getUsers();
});

class CreateChatScreen extends ConsumerStatefulWidget {
  final bool initialIsGroupChat;
  
  const CreateChatScreen({
    super.key,
    this.initialIsGroupChat = true,
  });

  @override
  ConsumerState<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends ConsumerState<CreateChatScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  late bool _isGroupChat;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _isGroupChat = widget.initialIsGroupChat;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать чат'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedUserIds.isEmpty ? null : _createChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Переключатель типа чата
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Личный'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Группа'),
                  icon: Icon(Icons.group),
                ),
              ],
              selected: {_isGroupChat},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isGroupChat = selection.first;
                  if (!_isGroupChat) {
                    // Для личного чата можно выбрать только одного
                    if (_selectedUserIds.length > 1) {
                      _selectedUserIds.clear();
                    }
                  }
                });
              },
            ),
          ),

          // Название группы (только для групповых чатов)
          if (_isGroupChat)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Название группы',
                  hintText: 'Введите название',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Поиск пользователей
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск пользователей',
                hintText: 'Имя или номер телефона',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(height: 8),

          // Выбранные пользователи
          if (_selectedUserIds.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: usersAsync.when(
                data: (users) {
                  final selectedUsers = users
                      .where((u) => _selectedUserIds.contains(u.id))
                      .toList();
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedUsers.length,
                    itemBuilder: (context, index) {
                      final user = selectedUsers[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            child: Text(
                              user.displayName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          label: Text(user.displayName),
                          onDeleted: () {
                            setState(() {
                              _selectedUserIds.remove(user.id);
                            });
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

          const Divider(),

          // Список пользователей
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Фильтруем пользователей по поисковому запросу
                final filteredUsers = _searchQuery.isEmpty
                    ? users
                    : users.where((user) {
                        return user.displayName
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            user.phoneNumber
                                .toLowerCase()
                                .contains(_searchQuery);
                      }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Text('Пользователи не найдены'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            if (!_isGroupChat) {
                              // Для личного чата - только один пользователь
                              _selectedUserIds.clear();
                            }
                            _selectedUserIds.add(user.id);
                          } else {
                            _selectedUserIds.remove(user.id);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        backgroundImage:
                            user.avatar != null ? NetworkImage(user.avatar!) : null,
                        child: user.avatar == null
                            ? Text(
                                user.displayName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.phoneNumber),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Ошибка: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(usersProvider),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createChat() async {
    if (_selectedUserIds.isEmpty) {
      return;
    }

    // Валидация для группового чата
    if (_isGroupChat && _groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название группы'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final createdChat = await ref.read(chatsProvider.notifier).createChat(
            title: _isGroupChat ? _groupNameController.text.trim() : null,
            participantIds: _selectedUserIds.toList(),
          );

      if (mounted && createdChat != null) {
        // Закрываем экран создания чата
        Navigator.of(context).pop();
        
        // Открываем созданный чат
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: createdChat.id),
          ),
        );
      } else if (mounted && createdChat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось создать чат'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания чата: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

