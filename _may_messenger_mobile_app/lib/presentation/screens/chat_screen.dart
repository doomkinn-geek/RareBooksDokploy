import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/messages_provider.dart';
import '../providers/signalr_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../../data/models/chat_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/fcm_service.dart';
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
    
    // Add scroll listener to mark messages as read when scrolled to bottom
    _scrollController.addListener(_onScroll);
    
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
      
      // Уведомить NotificationService и FCM что пользователь в этом чате
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.setCurrentChat(widget.chatId);
      
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.setCurrentChat(widget.chatId);
      
      // Обнуляем счетчик непрочитанных сообщений
      ref.read(chatsProvider.notifier).clearUnreadCount(widget.chatId);
      
      // Mark messages as read after a short delay to ensure messages are loaded
      await Future.delayed(const Duration(milliseconds: 500));
      ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
    });
  }
  
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // Check if scrolled to bottom (with small threshold)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 100.0; // pixels from bottom
    
    if (maxScroll - currentScroll <= threshold) {
      // User is at the bottom, mark messages as read
      ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
    }
  }

  @override
  void dispose() {
    // Refresh chats list when leaving chat screen to update preview
    ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
    
    // Очистить текущий чат при выходе
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.setCurrentChat(null);
    
    final fcmService = ref.read(fcmServiceProvider);
    fcmService.setCurrentChat(null);
    
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
    final chatsState = ref.watch(chatsProvider);
    final contactsNames = ref.watch(contactsNamesProvider);

    // Find current chat
    final currentChat = chatsState.chats.firstWhere(
      (chat) => chat.id == widget.chatId,
      orElse: () => Chat(
        id: widget.chatId,
        type: ChatType.private,
        title: 'Чат',
        unreadCount: 0,
        createdAt: DateTime.now(),
      ),
    );

    // Get display title (use contact name for private chats)
    String displayTitle = currentChat.title;
    if (currentChat.type == ChatType.private && currentChat.otherParticipantId != null) {
      final contactName = contactsNames[currentChat.otherParticipantId!];
      if (contactName != null && contactName.isNotEmpty) {
        displayTitle = contactName;
      }
    }
    if (displayTitle.isEmpty) {
      displayTitle = 'Чат';
    }

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messagesState.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
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


