import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/participant_model.dart';
import '../../data/services/contacts_service.dart';
import '../../core/constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/contacts_names_provider.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String chatId;
  
  const GroupSettingsScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  List<Participant> _participants = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Participant? _currentUserParticipant;
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }
  
  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final apiDataSource = ref.read(apiDataSourceProvider);
      final participants = await apiDataSource.getParticipants(widget.chatId);
      
      final currentUserId = ref.read(profileProvider).profile?.id;
      
      setState(() {
        _participants = participants;
        _currentUserParticipant = participants
            .where((p) => p.id == currentUserId)
            .firstOrNull;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  /// Check if current user can add/remove participants
  bool get canManageParticipants {
    return _currentUserParticipant?.isOwner == true ||
           _currentUserParticipant?.isAdmin == true;
  }
  
  /// Check if current user can manage admins
  bool get canManageAdmins {
    return _currentUserParticipant?.isOwner == true;
  }
  
  /// Check if current user is owner (can change avatar)
  bool get isOwner {
    return _currentUserParticipant?.isOwner == true;
  }
  
  Future<void> _pickGroupAvatar(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() => _isSaving = true);
        
        try {
          final apiDataSource = ref.read(apiDataSourceProvider);
          await apiDataSource.uploadGroupAvatar(widget.chatId, image.path);
          
          // Refresh chats to get updated avatar
          await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аватарка группы обновлена')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _showAvatarOptions() {
    final chatsState = ref.read(chatsProvider);
    final currentChat = chatsState.chats.where((c) => c.id == widget.chatId).firstOrNull;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickGroupAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _pickGroupAvatar(ImageSource.camera);
              },
            ),
            if (currentChat?.avatar != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить аватарку', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteGroupAvatar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _deleteGroupAvatar() async {
    setState(() => _isSaving = true);
    
    try {
      final apiDataSource = ref.read(apiDataSourceProvider);
      await apiDataSource.deleteGroupAvatar(widget.chatId);
      
      // Refresh chats to get updated avatar
      await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аватарка группы удалена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  Future<void> _editGroupTitle() async {
    final chatsState = ref.read(chatsProvider);
    final currentChat = chatsState.chats.where((c) => c.id == widget.chatId).firstOrNull;
    
    final controller = TextEditingController(text: currentChat?.title ?? '');
    
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить название группы'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название группы',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    
    if (newTitle != null && newTitle.trim().isNotEmpty && mounted) {
      setState(() => _isSaving = true);
      
      try {
        final apiDataSource = ref.read(apiDataSourceProvider);
        await apiDataSource.updateGroupTitle(widget.chatId, newTitle.trim());
        
        // Refresh chats to get updated title
        await ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Название группы обновлено')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
  
  Future<void> _addParticipants() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => _AddParticipantsScreen(
          chatId: widget.chatId,
          existingParticipantIds: _participants.map((p) => p.id).toList(),
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        final apiDataSource = ref.read(apiDataSourceProvider);
        await apiDataSource.addParticipants(widget.chatId, result);
        await _loadParticipants();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Добавлено ${result.length} участников')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _removeParticipant(Participant participant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить участника'),
        content: Text('Удалить ${participant.displayName} из группы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final apiDataSource = ref.read(apiDataSourceProvider);
        await apiDataSource.removeParticipant(widget.chatId, participant.id);
        await _loadParticipants();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${participant.displayName} удален из группы')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _toggleAdmin(Participant participant) async {
    try {
      final apiDataSource = ref.read(apiDataSourceProvider);
      
      if (participant.isAdmin) {
        await apiDataSource.demoteAdmin(widget.chatId, participant.id);
      } else {
        await apiDataSource.promoteToAdmin(widget.chatId, participant.id);
      }
      
      await _loadParticipants();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(participant.isAdmin 
                ? '${participant.displayName} больше не администратор'
                : '${participant.displayName} назначен администратором'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
  
  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Покинуть группу'),
        content: const Text('Вы уверены, что хотите покинуть эту группу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final apiDataSource = ref.read(apiDataSourceProvider);
        await apiDataSource.leaveChat(widget.chatId);
        
        // Refresh chats list
        ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
        
        if (mounted) {
          // Go back to main screen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsProvider);
    final currentChat = chatsState.chats.where((c) => c.id == widget.chatId).firstOrNull;
    final contactsNames = ref.watch(contactsNamesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(currentChat?.title ?? 'Настройки группы'),
        actions: [
          if (canManageParticipants)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _addParticipants,
              tooltip: 'Добавить участников',
            ),
        ],
      ),
      body: _buildBody(contactsNames),
    );
  }
  
  Widget _buildBody(Map<String, String> contactsNames) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadParticipants,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    final chatsState = ref.watch(chatsProvider);
    final currentChat = chatsState.chats.where((c) => c.id == widget.chatId).firstOrNull;
    final avatarUrl = currentChat?.avatar != null 
        ? '${ApiConstants.baseUrl}${currentChat!.avatar}' 
        : null;
    
    return RefreshIndicator(
      onRefresh: _loadParticipants,
      child: ListView(
        children: [
          // Group Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Group Avatar
                GestureDetector(
                  onTap: isOwner && !_isSaving ? _showAvatarOptions : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage: avatarUrl != null 
                            ? NetworkImage(avatarUrl) 
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                currentChat?.title.isNotEmpty == true 
                                    ? currentChat!.title[0].toUpperCase() 
                                    : 'G',
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      if (isOwner)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (_isSaving)
                        const Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Group Title
                GestureDetector(
                  onTap: canManageParticipants && !_isSaving ? _editGroupTitle : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          currentChat?.title ?? 'Группа',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (canManageParticipants) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                ),
                
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Нажмите на аватарку, чтобы изменить',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Participants section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.people),
                const SizedBox(width: 8),
                Text(
                  'Участники (${_participants.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          
          // Owners first, then admins, then members
          ..._sortParticipants().map((p) => _buildParticipantTile(p, contactsNames)),
          
          const Divider(height: 32),
          
          // Leave group button
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Покинуть группу',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _leaveGroup,
          ),
        ],
      ),
    );
  }
  
  List<Participant> _sortParticipants() {
    return List.from(_participants)..sort((a, b) {
      // Owners first
      if (a.isOwner && !b.isOwner) return -1;
      if (!a.isOwner && b.isOwner) return 1;
      // Then admins
      if (a.isAdmin && !b.isAdmin) return -1;
      if (!a.isAdmin && b.isAdmin) return 1;
      // Then by name
      return a.displayName.compareTo(b.displayName);
    });
  }
  
  Widget _buildParticipantTile(Participant participant, Map<String, String> contactsNames) {
    final currentUserId = ref.read(profileProvider).profile?.id;
    final isCurrentUser = participant.id == currentUserId;
    
    // Use contact name if available
    final displayName = contactsNames[participant.id] ?? participant.displayName;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: participant.isOwner 
            ? Colors.amber
            : participant.isAdmin 
                ? Colors.blue 
                : Theme.of(context).colorScheme.primary,
        child: Text(
          displayName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isCurrentUser ? '$displayName (Вы)' : displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        participant.roleDisplayName,
        style: TextStyle(
          color: participant.isOwner 
              ? Colors.amber[700]
              : participant.isAdmin 
                  ? Colors.blue 
                  : Colors.grey,
        ),
      ),
      trailing: _buildParticipantActions(participant, isCurrentUser),
    );
  }
  
  Widget? _buildParticipantActions(Participant participant, bool isCurrentUser) {
    if (isCurrentUser) return null;
    if (participant.isOwner) return null;
    
    if (!canManageParticipants) return null;
    
    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'remove':
            _removeParticipant(participant);
            break;
          case 'toggle_admin':
            _toggleAdmin(participant);
            break;
        }
      },
      itemBuilder: (context) => [
        if (canManageAdmins)
          PopupMenuItem(
            value: 'toggle_admin',
            child: Row(
              children: [
                Icon(
                  participant.isAdmin ? Icons.remove_moderator : Icons.admin_panel_settings,
                  color: participant.isAdmin ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(participant.isAdmin ? 'Снять админа' : 'Назначить админом'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              const Icon(Icons.person_remove, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Удалить', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Screen to select contacts to add as participants
class _AddParticipantsScreen extends ConsumerStatefulWidget {
  final String chatId;
  final List<String> existingParticipantIds;
  
  const _AddParticipantsScreen({
    required this.chatId,
    required this.existingParticipantIds,
  });

  @override
  ConsumerState<_AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends ConsumerState<_AddParticipantsScreen> {
  List<RegisteredContact> _contacts = [];
  Map<String, String> _phoneBookNames = {};
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
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
    });
    
    try {
      // Check contacts permission
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }
      
      if (!status.isGranted) {
        setState(() {
          _error = 'Требуется доступ к контактам';
          _isLoading = false;
        });
        return;
      }
      
      final authRepo = ref.read(authRepositoryProvider);
      final token = await authRepo.getStoredToken();
      
      if (token == null) {
        setState(() {
          _error = 'Не авторизован';
          _isLoading = false;
        });
        return;
      }
      
      final contactsService = ContactsService(ref.read(apiDataSourceProvider).dio);
      final contacts = await contactsService.syncContacts(token);
      
      // Filter out existing participants
      final availableContacts = contacts.where(
        (c) => !widget.existingParticipantIds.contains(c.userId)
      ).toList();
      
      // Build phone book names mapping
      final localContacts = await contactsService.getAllContacts();
      final phoneBookNames = <String, String>{};
      
      for (final registered in availableContacts) {
        for (final local in localContacts) {
          if (local.phones.isNotEmpty) {
            final hash = contactsService.hashPhoneNumber(local.phones.first.number);
            if (hash == registered.phoneNumberHash) {
              phoneBookNames[registered.userId] = local.displayName;
              break;
            }
          }
        }
      }
      
      setState(() {
        _contacts = availableContacts;
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
  
  void _confirmSelection() {
    Navigator.of(context).pop(_selectedUserIds.toList());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить участников'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Добавить (${_selectedUserIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
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
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    if (_contacts.isEmpty) {
      return const Center(
        child: Text('Нет доступных контактов для добавления'),
      );
    }
    
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final isSelected = _selectedUserIds.contains(contact.userId);
        final displayName = _phoneBookNames[contact.userId] ?? contact.displayName;
        
        return CheckboxListTile(
          value: isSelected,
          onChanged: (selected) {
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
              ? Text(contact.displayName, style: const TextStyle(fontSize: 12))
              : null,
        );
      },
    );
  }
}

