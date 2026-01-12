import 'package:flutter/material.dart';

/// Menu action item for overflow menu
class _MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _MenuAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });
}

/// Telegram-style app bar that appears when messages are selected
/// Shows selected count and action buttons
/// Adapts to screen width - shows overflow menu on narrow screens
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

  /// Build list of all available actions
  List<_MenuAction> _buildAllActions(ThemeData theme) {
    final actions = <_MenuAction>[];
    
    // Reply - only for single message (primary action)
    if (selectedCount == 1 && onReply != null) {
      actions.add(_MenuAction(
        icon: Icons.reply,
        label: 'Ответить',
        onTap: onReply,
      ));
    }
    
    // Copy - only for text messages (primary action)
    if (canCopy) {
      actions.add(_MenuAction(
        icon: Icons.copy,
        label: 'Копировать',
        onTap: onCopy,
      ));
    }
    
    // Forward - always available (primary action)
    actions.add(_MenuAction(
      icon: Icons.forward,
      label: 'Переслать',
      onTap: onForward,
    ));
    
    // Share to other apps (secondary action)
    actions.add(_MenuAction(
      icon: Icons.share,
      label: 'Поделиться',
      onTap: onShare,
    ));
    
    // Edit - only for single own text message (secondary action)
    if (canEdit && onEdit != null) {
      actions.add(_MenuAction(
        icon: Icons.edit,
        label: 'Редактировать',
        onTap: onEdit,
      ));
    }
    
    // Info - only for single own message in group chat (secondary action)
    if (canShowInfo && onInfo != null) {
      actions.add(_MenuAction(
        icon: Icons.info_outline,
        label: 'Информация',
        onTap: onInfo,
      ));
    }
    
    // Delete - only own messages (always shown as icon if available)
    if (canDelete) {
      actions.add(_MenuAction(
        icon: Icons.delete,
        label: 'Удалить',
        onTap: onDelete,
        iconColor: theme.colorScheme.error,
      ));
    }
    
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allActions = _buildAllActions(theme);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available width for actions
        // AppBar: leading (48) + title (~40) + padding = ~100px
        // Each icon button is ~48px
        final availableWidth = constraints.maxWidth - 100;
        final iconWidth = 48.0;
        final maxVisibleIcons = (availableWidth / iconWidth).floor();
        
        // Determine how many actions to show as icons vs in overflow menu
        // Always show at least 2 icons if we have actions
        final visibleCount = maxVisibleIcons.clamp(2, allActions.length);
        final needsOverflow = allActions.length > visibleCount;
        
        // If we need overflow, reserve one slot for the overflow button
        final actualVisibleCount = needsOverflow ? visibleCount - 1 : visibleCount;
        
        // Split actions into visible and overflow
        final visibleActions = allActions.take(actualVisibleCount).toList();
        final overflowActions = needsOverflow 
            ? allActions.skip(actualVisibleCount).toList() 
            : <_MenuAction>[];
        
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
            // Visible icon buttons
            ...visibleActions.map((action) => IconButton(
              icon: Icon(action.icon),
              onPressed: action.onTap,
              tooltip: action.label,
              color: action.iconColor,
            )),
            
            // Overflow menu if needed
            if (overflowActions.isNotEmpty)
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Ещё',
                onSelected: (index) {
                  overflowActions[index].onTap?.call();
                },
                itemBuilder: (context) => overflowActions
                    .asMap()
                    .entries
                    .map((entry) => PopupMenuItem<int>(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(
                                entry.value.icon,
                                color: entry.value.iconColor ?? 
                                       theme.iconTheme.color,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(entry.value.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}
