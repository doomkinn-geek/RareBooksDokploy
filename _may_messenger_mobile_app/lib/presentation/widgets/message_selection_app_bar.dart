import 'package:flutter/material.dart';

/// Telegram-style app bar that appears when messages are selected
/// Shows selected count and action buttons
class MessageSelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final bool canEdit;       // Only for single message, own text message
  final bool canCopy;       // Only for text messages
  final bool canShowInfo;   // Only for single message, group chat, own message
  final bool canDelete;     // Only own messages
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onInfo;
  final VoidCallback? onReply;

  const MessageSelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.canEdit,
    required this.canCopy,
    required this.canShowInfo,
    required this.canDelete,
    required this.onClose,
    required this.onCopy,
    required this.onForward,
    required this.onShare,
    required this.onDelete,
    this.onEdit,
    this.onInfo,
    this.onReply,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onClose,
        tooltip: 'Отменить выбор',
      ),
      title: Text(
        selectedCount.toString(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        // Reply - only for single message
        if (selectedCount == 1 && onReply != null)
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: onReply,
            tooltip: 'Ответить',
          ),
        
        // Copy - only for text messages
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
            tooltip: 'Копировать',
          ),
        
        // Forward - always available
        IconButton(
          icon: const Icon(Icons.forward),
          onPressed: onForward,
          tooltip: 'Переслать',
        ),
        
        // Share to other apps
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: onShare,
          tooltip: 'Поделиться',
        ),
        
        // Edit - only for single own text message
        if (canEdit && onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
            tooltip: 'Редактировать',
          ),
        
        // Info - only for single own message in group chat
        if (canShowInfo && onInfo != null)
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: onInfo,
            tooltip: 'Информация',
          ),
        
        // Delete - only own messages
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
            tooltip: 'Удалить',
            color: theme.colorScheme.error,
          ),
      ],
    );
  }
}

