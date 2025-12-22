import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/messages_provider.dart';
import '../providers/signalr_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/fcm_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/connection_status_banner.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? highlightMessageId;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.highlightMessageId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    
    // Set highlighted message if provided
    if (widget.highlightMessageId != null) {
      _highlightedMessageId = widget.highlightMessageId;
      // Clear highlight after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
    
    // Add scroll listener to mark messages as read when scrolled to bottom
    _scrollController.addListener(_onScroll);
    
    // Join chat via SignalR
    Future.microtask(() async {
      final signalRService = ref.read(signalRServiceProvider);
      
      await signalRService.joinChat(widget.chatId);
      
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
    // Don't force refresh chats here - let local updates handle it
    // ref.read(chatsProvider.notifier).loadChats(forceRefresh: true);
    
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

  void _scrollToHighlightedMessage(List<Message> messages) {
    if (!_scrollController.hasClients || _highlightedMessageId == null) return;
    
    final index = messages.indexWhere((m) => m.id == _highlightedMessageId);
    if (index == -1) {
      // Message not found, scroll to bottom
      _scrollToBottom();
      return;
    }
    
    // Calculate approximate scroll position (assuming each message is ~100px)
    final approximateItemHeight = 100.0;
    final scrollPosition = index * approximateItemHeight;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          scrollPosition.clamp(0, maxScroll),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
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

    // Scroll to bottom when new messages arrive or to highlight message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messagesState.messages.isNotEmpty) {
        if (_highlightedMessageId != null) {
          _scrollToHighlightedMessage(messagesState.messages);
        } else {
          _scrollToBottom();
        }
      }
    });

    // Build online status subtitle for private chats
    String? onlineStatusText;
    if (currentChat.type == ChatType.private && currentChat.otherParticipantId != null) {
      if (currentChat.otherParticipantIsOnline == true) {
        onlineStatusText = 'онлайн';
      } else if (currentChat.otherParticipantLastSeenAt != null) {
        final now = DateTime.now();
        final diff = now.difference(currentChat.otherParticipantLastSeenAt!);
        
        if (diff.inMinutes < 1) {
          onlineStatusText = 'только что';
        } else if (diff.inMinutes < 60) {
          onlineStatusText = 'был(а) ${diff.inMinutes} мин назад';
        } else if (diff.inHours < 24) {
          onlineStatusText = 'был(а) ${diff.inHours} ч назад';
        } else if (diff.inDays < 7) {
          onlineStatusText = 'был(а) ${diff.inDays} дн назад';
        } else {
          onlineStatusText = 'был(а) давно';
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(displayTitle),
            if (onlineStatusText != null)
              Text(
                onlineStatusText,
                style: TextStyle(
                  fontSize: 12,
                  color: onlineStatusText == 'онлайн' 
                      ? Colors.green 
                      : Colors.grey[400],
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
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
          const ConnectionStatusBanner(),
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
                          final isHighlighted = message.id == _highlightedMessageId;
                          return MessageBubble(
                            message: message,
                            isHighlighted: isHighlighted,
                          );
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
            onSendImage: (imagePath) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendImageMessage(imagePath);
            },
          ),
        ],
      ),
    );
  }
}


