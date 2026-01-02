import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/message_model.dart';

/// Action types for message context menu
enum MessageAction {
  reply,
  forward,
  edit,
  delete,
  copy,
}

/// Context menu for message actions
class MessageContextMenu extends StatelessWidget {
  final Message message;
  final bool isMyMessage;
  final Function(MessageAction) onAction;
  final VoidCallback onDismiss;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              context,
              Icons.reply,
              'Ответить',
              MessageAction.reply,
            ),
            _buildMenuItem(
              context,
              Icons.forward,
              'Переслать',
              MessageAction.forward,
            ),
            if (isMyMessage && message.type == MessageType.text && !message.isDeleted)
              _buildMenuItem(
                context,
                Icons.edit,
                'Редактировать',
                MessageAction.edit,
              ),
            if (message.type == MessageType.text)
              _buildMenuItem(
                context,
                Icons.copy,
                'Копировать',
                MessageAction.copy,
              ),
            if (isMyMessage && !message.isDeleted)
              _buildMenuItem(
                context,
                Icons.delete,
                'Удалить',
                MessageAction.delete,
                isDestructive: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    MessageAction action, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : null;
    
    return InkWell(
      onTap: () {
        onDismiss();
        if (action == MessageAction.copy && message.content != null) {
          Clipboard.setData(ClipboardData(text: message.content!));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Скопировано'),
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          onAction(action);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the context menu as an overlay
void showMessageContextMenu({
  required BuildContext context,
  required Message message,
  required bool isMyMessage,
  required Offset position,
  required Function(MessageAction) onAction,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) {
      return Stack(
        children: [
          // Background tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: () => overlayEntry.remove(),
              child: Container(color: Colors.black12),
            ),
          ),
          // Menu positioned near the tap
          Positioned(
            left: position.dx.clamp(16.0, MediaQuery.of(context).size.width - 180),
            top: position.dy.clamp(80.0, MediaQuery.of(context).size.height - 300),
            child: MessageContextMenu(
              message: message,
              isMyMessage: isMyMessage,
              onAction: onAction,
              onDismiss: () => overlayEntry.remove(),
            ),
          ),
        ],
      );
    },
  );
  
  overlay.insert(overlayEntry);
}

