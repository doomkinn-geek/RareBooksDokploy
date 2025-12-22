import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_model.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/chats_provider.dart';

class ChatListItem extends ConsumerWidget {
  final Chat chat;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить чат'),
        content: const Text('Чат и все сообщения будут удалены у всех участников'),
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

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(chatsProvider.notifier).deleteChat(chat.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Чат удален'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось удалить чат'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  String _formatLastMessage(Map<String, String> contactsNames) {
    if (chat.lastMessage == null) {
      return 'Нет сообщений';
    }
    
    final content = chat.lastMessage!.content ?? '[Голосовое сообщение]';
    
    // For group chats, prepend sender name
    if (chat.type == ChatType.group) {
      final senderName = contactsNames[chat.lastMessage!.senderId] 
                         ?? chat.lastMessage!.senderName;
      return '$senderName: $content';
    }
    
    return content;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get contacts mapping
    final contactsNames = ref.watch(contactsNamesProvider);
    
    // For private chats, try to use name from phone contacts
    String displayTitle = chat.title;
    
    if (chat.type == ChatType.private && chat.otherParticipantId != null) {
      final contactName = contactsNames[chat.otherParticipantId!];
      if (contactName != null && contactName.isNotEmpty) {
        displayTitle = contactName;
      }
    }
    
    // Handle empty title
    if (displayTitle.isEmpty) {
      displayTitle = chat.type == ChatType.private ? 'Приватный чат' : 'Без названия';
    }
    
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showDeleteDialog(context, ref),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: chat.avatar != null
                  ? NetworkImage(chat.avatar!)
                  : null,
              child: chat.avatar == null
                  ? Text(displayTitle[0].toUpperCase())
                  : null,
            ),
            // Online status indicator for private chats
            if (chat.type == ChatType.private && 
                chat.otherParticipantId != null && 
                chat.otherParticipantIsOnline == true)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _formatLastMessage(contactsNames),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (chat.lastMessage != null)
              Text(
                DateFormat('HH:mm').format(chat.lastMessage!.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (chat.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


