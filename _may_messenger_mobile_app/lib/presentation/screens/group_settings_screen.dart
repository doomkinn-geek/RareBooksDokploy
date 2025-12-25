import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/participant_model.dart';
import '../../data/services/contacts_service.dart';
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
  String? _error;
  Participant? _currentUserParticipant;
  
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
    
    return RefreshIndicator(
      onRefresh: _loadParticipants,
      child: ListView(
        children: [
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

