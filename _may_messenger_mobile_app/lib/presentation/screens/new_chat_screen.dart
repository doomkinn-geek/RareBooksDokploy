import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../data/services/contacts_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/constants/api_constants.dart';
import '../providers/chats_provider.dart';
import '../providers/auth_provider.dart';

final contactsServiceProvider = Provider((ref) => ContactsService(Dio()));

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  List<RegisteredContact> _contacts = [];
  bool _isLoading = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _permissionDenied = false;
    });

    try {
      final contactsService = ref.read(contactsServiceProvider);
      
      // Request permission
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
        return;
      }

      // Get token
      final authRepo = ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Sync and get registered contacts
      final contacts = await contactsService.syncContacts(token);
      
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createOrOpenChat(RegisteredContact contact) async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Call backend to create or get existing chat
      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}/api/chats/create-or-get',
        data: {
          'targetUserId': contact.userId,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        // Refresh chats list
        ref.read(chatsProvider.notifier).loadChats();
        
        // Navigate back
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Чат с ${contact.displayName} открыт')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания чата: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый чат'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Доступ к контактам',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Для создания чатов необходимо предоставить доступ к контактам телефона. Мы используем их только для поиска зарегистрированных пользователей May Messenger.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await FlutterContacts.openExternalPick();
                  _loadContacts();
                },
                child: const Text('Открыть настройки'),
              ),
              TextButton(
                onPressed: _loadContacts,
                child: const Text('Повторить попытку'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Ошибка: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Нет зарегистрированных контактов',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пока никто из ваших контактов не использует May Messenger',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('Обновить'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(contact.displayName[0].toUpperCase()),
          ),
          title: Text(contact.displayName),
          trailing: const Icon(Icons.chat_bubble_outline),
          onTap: () => _createOrOpenChat(contact),
        );
      },
    );
  }
}
