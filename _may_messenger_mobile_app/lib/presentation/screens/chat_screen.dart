import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/messages_provider.dart';
import '../providers/signalr_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/logger_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    
    // #region agent log
    _logger.debug('chat_screen.initState', '[H2] ChatScreen opened', {'chatId': widget.chatId});
    // #endregion
    
    // Join chat via SignalR
    Future.microtask(() async {
      final signalRService = ref.read(signalRServiceProvider);
      
      // #region agent log
      await _logger.debug('chat_screen.initState.beforeJoin', '[H2] Before JoinChat', {'chatId': widget.chatId, 'isConnected': '${signalRService.isConnected}'});
      // #endregion
      
      await signalRService.joinChat(widget.chatId);
      
      // #region agent log
      await _logger.debug('chat_screen.initState.afterJoin', '[H2] After JoinChat', {'chatId': widget.chatId});
      // #endregion
      
      // Уведомить NotificationService что пользователь в этом чате
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.setCurrentChat(widget.chatId);
    });
  }

  @override
  void dispose() {
    // Очистить текущий чат при выходе
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.setCurrentChat(null);
    
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesProvider(widget.chatId));

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messagesState.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чат'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show chat info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesState.isLoading && messagesState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messagesState.messages.isEmpty
                    ? const Center(child: Text('Нет сообщений'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messagesState.messages.length,
                        itemBuilder: (context, index) {
                          final message = messagesState.messages[index];
                          return MessageBubble(message: message);
                        },
                      ),
          ),
          MessageInput(
            chatId: widget.chatId,
            isSending: messagesState.isSending,
            onSendMessage: (content) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendMessage(content);
            },
            onSendAudio: (audioPath) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendAudioMessage(audioPath);
            },
          ),
        ],
      ),
    );
  }
}


