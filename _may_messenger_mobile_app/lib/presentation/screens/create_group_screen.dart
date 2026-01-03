import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/services/contacts_service.dart';
import '../../core/constants/api_constants.dart';
import '../providers/chats_provider.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart';

final contactsServiceProvider = Provider((ref) => ContactsService(Dio()));

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<RegisteredContact> _contacts = [];
  Map<String, String> _phoneBookNames = {}; // Mapping userId -> phone book name
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  bool _permissionDenied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _permissionDenied = false;
    });

    try {
      final contactsService = ref.read(contactsServiceProvider);
      
      // Check permission status using permission_handler
      var permissionStatus = await Permission.contacts.status;
      
      // If not granted, request it
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.contacts.request();
      }
      
      if (!permissionStatus.isGranted) {
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
      
      // Get local contacts to build name mapping
      final localContacts = await contactsService.getAllContacts();
      final phoneBookNames = <String, String>{};
      
      // Build mapping: for each registered contact, find their name in phone book
      for (final registered in contacts) {
        for (final local in localContacts) {
          if (local.phones.isNotEmpty) {
            final hash = contactsService.hashPhoneNumber(local.phones.first.number);
            
            if (hash == registered.phoneNumberHash) {
              // Found match - use phone book name
              phoneBookNames[registered.userId] = local.displayName;
              break;
            }
          }
        }
      }
      
      setState(() {
        _contacts = contacts;
        _phoneBookNames = phoneBookNames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    // Validate
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одного участника'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 80, left: 16, right: 16),
        ),
      );
      return;
    }

    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название группы'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 80, left: 16, right: 16),
        ),
      );
      return;
    }

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Validate participant IDs are valid GUIDs
      final participantIds = _selectedUserIds.toList();
      print('[GROUP_CREATE] Creating group with title: ${_groupNameController.text.trim()}');
      print('[GROUP_CREATE] Participants: $participantIds');
      
      for (final id in participantIds) {
        // Validate GUID format
        final guidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (!guidRegex.hasMatch(id)) {
          throw Exception('Invalid participant ID format: $id');
        }
      }

      // Call backend to create group chat
      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}/api/chats',
        data: {
          'title': _groupNameController.text.trim(),
          'participantIds': participantIds,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => true, // Accept all status codes to see error body
        ),
      );
      
      print('[GROUP_CREATE] Response status: ${response.statusCode}');
      print('[GROUP_CREATE] Response data: ${response.data}');

      if (response.statusCode == 200) {
        if (mounted) {
          final chatData = response.data;
          final chatId = chatData['id'] as String;
          
          // Refresh chats list with force refresh and wait for completion
          await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
          
          // Navigate back and open the chat
          if (mounted) {
            Navigator.pop(context);
            
            // Open the chat screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chatId: chatId),
              ),
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Группа "${_groupNameController.text.trim()}" создана'),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
              ),
            );
          }
        }
      } else {
        // Handle error responses
        String errorMessage = 'Ошибка ${response.statusCode}';
        if (response.data != null) {
          if (response.data is Map) {
            errorMessage = response.data['message'] ?? response.data['title'] ?? response.data.toString();
          } else {
            errorMessage = response.data.toString();
          }
        }
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      print('[GROUP_CREATE] DioException: ${e.type} - ${e.message}');
      print('[GROUP_CREATE] Response data: ${e.response?.data}');
      
      String errorMessage = 'Ошибка сети';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['message'] ?? e.response!.data['title'] ?? e.response!.data.toString();
        } else {
          errorMessage = e.response!.data.toString();
        }
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания группы: $errorMessage'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      print('[GROUP_CREATE] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания группы: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать группу'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectedUserIds.isEmpty ? null : _createGroup,
          ),
        ],
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
                'Для создания групп необходимо предоставить доступ к контактам телефона.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await openAppSettings();
                  _loadContacts();
                },
                child: const Text('Открыть настройки'),
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
              Text(
                'Ошибка загрузки контактов',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadContacts,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Group name input
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: 'Название группы',
              hintText: 'Введите название',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.group),
            ),
          ),
        ),
        
        // Selected count
        if (_selectedUserIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Выбрано: ${_selectedUserIds.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        
        const SizedBox(height: 8),
        const Divider(),
        
        // Contacts list
        Expanded(
          child: _contacts.isEmpty
              ? const Center(
                  child: Text('Нет зарегистрированных контактов'),
                )
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final isSelected = _selectedUserIds.contains(contact.userId);
                    
                    // Use phone book name if available, otherwise use server name
                    final displayName = _phoneBookNames[contact.userId] ?? contact.displayName;
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedUserIds.add(contact.userId);
                          } else {
                            _selectedUserIds.remove(contact.userId);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(displayName),
                      subtitle: contact.displayName != displayName 
                          ? Text(contact.displayName, style: const TextStyle(fontSize: 12, color: Colors.grey))
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
