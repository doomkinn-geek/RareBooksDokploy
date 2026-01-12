import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../core/themes/app_theme.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/chats_provider.dart';
import 'cached_avatar.dart';

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
    
    // Determine content based on message type
    String content;
    switch (chat.lastMessage!.type) {
      case MessageType.audio:
        content = '🎤 Голосовое сообщение';
      case MessageType.image:
        content = '📷 Фото';
      case MessageType.file:
        content = '📎 Файл';
      case MessageType.text:
        content = chat.lastMessage!.content ?? '';
      case MessageType.poll:
        final question = chat.lastMessage!.pollData?['question'] ?? 'Голосование';
        content = '📊 $question';
    }
    
    // For group chats, prepend sender name
    if (chat.type == ChatType.group) {
      final senderName = contactsNames[chat.lastMessage!.senderId] 
                         ?? chat.lastMessage!.senderName;
      return '$senderName: $content';
    }
    
    return content;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // Today - show time
      return DateFormat('HH:mm').format(dateTime.toLocal());
    } else if (today.difference(messageDate).inDays == 1) {
      // Yesterday
      return 'Вчера';
    } else if (today.difference(messageDate).inDays < 7) {
      // This week - show day name
      return DateFormat('E', 'ru').format(dateTime.toLocal());
    } else {
      // Older - show date
      return DateFormat('dd.MM.yy').format(dateTime.toLocal());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
    
    // Get avatar path and user ID for caching
    final avatarPath = chat.displayAvatar;
    final avatarUserId = chat.type == ChatType.private 
        ? chat.otherParticipantId 
        : chat.id;
    
    final hasUnread = chat.unreadCount > 0;
    final lastMessagePreview = _formatLastMessage(contactsNames);
    
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showDeleteDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CachedAvatar(
                  userId: avatarUserId,
                  avatarPath: avatarPath,
                  fallbackText: displayTitle,
                  radius: 28, // Larger avatar (56px diameter)
                  backgroundColor: AppColors.primaryGreen,
                ),
                // Online status indicator
                if (chat.type == ChatType.private && 
                    chat.otherParticipantId != null && 
                    chat.otherParticipantIsOnline == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.onlineIndicator,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and time row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessage != null)
                        Text(
                          _formatTime(chat.lastMessage!.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread 
                                ? AppColors.primaryGreen 
                                : (isDark ? Colors.white54 : Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Message preview and unread badge row
                  Row(
                    children: [
                      // Check marks for sent messages
                      if (chat.lastMessage != null && _isOwnMessage(ref)) ...[
                        _buildStatusIcon(chat.lastMessage!.status),
                        const SizedBox(width: 4),
                      ],
                      
                      // Message preview
                      Expanded(
                        child: Text(
                          lastMessagePreview,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? (isDark ? Colors.white70 : Colors.black87)
                                : (isDark ? Colors.white54 : Colors.grey[600]),
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Unread badge
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.unreadBadge,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  bool _isOwnMessage(WidgetRef ref) {
    if (chat.lastMessage == null) return false;
    // Check if the last message sender ID matches current user
    // For now, simplified check - return false
    return false;
  }
  
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 16,
          color: Colors.grey[400],
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 16,
          color: Colors.grey[400],
        );
      case MessageStatus.read:
      case MessageStatus.played:
        return const Icon(
          Icons.done_all,
          size: 16,
          color: AppColors.readCheckmarks,
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 16,
          color: AppColors.error,
        );
    }
  }
}
