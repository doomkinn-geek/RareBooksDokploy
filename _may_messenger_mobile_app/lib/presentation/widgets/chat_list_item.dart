import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_model.dart';

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Handle empty title for private chats
    final displayTitle = chat.title.isEmpty 
        ? (chat.type == ChatType.private ? 'Приватный чат' : 'Без названия')
        : chat.title;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: chat.avatar != null
            ? NetworkImage(chat.avatar!)
            : null,
        child: chat.avatar == null
            ? Text(displayTitle[0].toUpperCase())
            : null,
      ),
      title: Text(
        displayTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: chat.lastMessage != null
          ? Text(
              chat.lastMessage!.content ?? '[Голосовое сообщение]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const Text('Нет сообщений'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.lastMessage != null)
            Text(
              DateFormat('HH:mm').format(chat.lastMessage!.createdAt),
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
      onTap: onTap,
    );
  }
}


