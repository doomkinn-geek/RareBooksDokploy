import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/messages_provider.dart';
import '../providers/signalr_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/typing_provider.dart';
import '../providers/online_status_provider.dart';
import '../providers/auth_provider.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/fcm_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/typing_animation.dart';
import 'group_settings_screen.dart';

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
  bool _hasInitialScrolled = false; // Track if we've scrolled on first load
  bool _isPeriodicStatusUpdateActive = false;
  bool _showScrollToBottomButton = false; // Show FAB when scrolled up

  @override
  void initState() {
    super.initState();
    
    print('[CHAT_SCREEN] initState called - chatId: ${widget.chatId}, highlightMessageId: ${widget.highlightMessageId}');
    
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
    // and to show/hide scroll-to-bottom FAB
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateScrollToBottomButton);
    
    // CRITICAL: Perform reliable sync when opening chat
    // This ensures we have the latest data even after push notification
    _performReliableChatSync();
  }
  
  /// Perform reliable synchronization when chat screen opens
  /// This handles the case when app was opened from push notification
  Future<void> _performReliableChatSync() async {
    print('[CHAT_SCREEN] Starting reliable chat sync for ${widget.chatId}');
    
    try {
      // STEP 1: Force refresh messages first (most important)
      print('[CHAT_SCREEN] Step 1: Force refreshing messages...');
      await ref.read(messagesProvider(widget.chatId).notifier).loadMessages(forceRefresh: true);
      
      // STEP 2: Join chat via SignalR
      print('[CHAT_SCREEN] Step 2: Joining chat via SignalR...');
      final signalRService = ref.read(signalRServiceProvider);
      await signalRService.joinChat(widget.chatId);
      
      // STEP 3: Set current chat for notifications
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.setCurrentChat(widget.chatId);
      await notificationService.cancelNotificationsForChat(widget.chatId);
      
      final fcmService = ref.read(fcmServiceProvider);
      fcmService.setCurrentChat(widget.chatId);
      
      // STEP 4: Clear unread count
      ref.read(chatsProvider.notifier).clearUnreadCount(widget.chatId);
      
      // STEP 5: Wait for messages to load, then mark as read
      // Wait until messages are actually loaded (check isLoading state)
      int waitAttempts = 0;
      while (ref.read(messagesProvider(widget.chatId)).isLoading && waitAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitAttempts++;
      }
      
      print('[CHAT_SCREEN] Messages loaded, marking as read...');
      ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
    
      // STEP 6: Load user status immediately
      await _loadUserStatus();
      
      // STEP 7: Start periodic status updates
      _startPeriodicStatusUpdate();
      
      print('[CHAT_SCREEN] Reliable chat sync completed');
    } catch (e) {
      print('[CHAT_SCREEN] Error during reliable chat sync: $e');
      // Non-fatal - continue with whatever data we have
    }
  }
  
  /// Load user online status from API
  Future<void> _loadUserStatus() async {
    try {
      final chatsState = ref.read(chatsProvider);
      final currentChat = chatsState.chats.where((chat) => chat.id == widget.chatId).firstOrNull;
      
      if (currentChat?.type == ChatType.private && 
          currentChat?.otherParticipantId != null) {
          final userRepository = ref.read(userRepositoryProvider);
          final statuses = await userRepository.getUsersStatus([currentChat!.otherParticipantId!]);
          
          if (statuses.isNotEmpty && mounted) {
            final status = statuses.first;
            ref.read(onlineUsersProvider.notifier).setUserOnline(status.userId, status.isOnline);
            
            if (status.lastSeenAt != null) {
              ref.read(lastSeenMapProvider.notifier).setLastSeen(status.userId, status.lastSeenAt!);
            }
          
          print('[CHAT_SCREEN] User status loaded: ${status.isOnline ? "online" : "offline"}');
        }
          }
        } catch (e) {
      print('[CHAT_SCREEN] Failed to load user status: $e');
    }
  }
  
  /// Start periodic status updates every 30 seconds while chat is open
  void _startPeriodicStatusUpdate() {
    if (_isPeriodicStatusUpdateActive) return;
    _isPeriodicStatusUpdateActive = true;
    
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      
      _loadUserStatus();
      
      // Continue periodic updates
      if (mounted) {
        _isPeriodicStatusUpdateActive = false;
        _startPeriodicStatusUpdate();
      }
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

  void _updateScrollToBottomButton() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 500.0; // Show FAB when scrolled up more than 500px from bottom
    
    final shouldShow = maxScroll - currentScroll > threshold;
    if (shouldShow != _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = shouldShow;
      });
    }
  }

  /// Check if user is near bottom of the list (for auto-scroll on new message)
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 150.0; // Consider "near bottom" if within 150px
    
    return maxScroll - currentScroll <= threshold;
  }

  /// Auto-scroll to bottom if user is near the bottom
  void _autoScrollIfNearBottom() {
    if (_isNearBottom()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
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
  
  Widget _buildTypingIndicator() {
    final typingUsers = ref.watch(typingProvider).getTypingUsers(widget.chatId);
    
    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const TypingAnimation(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatTypingText(typingUsers),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTypingText(List<TypingUser> users) {
    if (users.length == 1) {
      return '${users[0].userName} пишет...';
    } else if (users.length == 2) {
      return '${users[0].userName} и ${users[1].userName} пишут...';
    } else {
      return '${users[0].userName} и еще ${users.length - 1} пишут...';
    }
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

    // Listen for new messages and auto-scroll if near bottom
    ref.listen<MessagesState>(messagesProvider(widget.chatId), (previous, next) {
      final prevCount = previous?.messages.length ?? 0;
      final nextCount = next.messages.length;
      
      // Auto-scroll only when new messages are added (not on initial load or status updates)
      if (nextCount > prevCount && _hasInitialScrolled) {
        _autoScrollIfNearBottom();
      }
    });

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

    // Scroll to bottom only on first load (not on every rebuild)
    if (!_hasInitialScrolled && 
        messagesState.messages.isNotEmpty && 
        !messagesState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_highlightedMessageId != null) {
          _scrollToHighlightedMessage(messagesState.messages);
        } else {
          _scrollToBottom();
        }
        _hasInitialScrolled = true;
      });
    }

    // Build online status subtitle for private chats
    String? onlineStatusText;
    if (currentChat.type == ChatType.private && currentChat.otherParticipantId != null) {
      // Check typing first (highest priority)
      final typingUsers = ref.watch(typingProvider).getTypingUsers(widget.chatId);
      if (typingUsers.isNotEmpty) {
        onlineStatusText = 'печатает...';
      } else {
        // Check online status
        final otherUserId = currentChat.otherParticipantId!;
        final onlineUsers = ref.watch(onlineUsersProvider);
        
        if (onlineUsers.contains(otherUserId)) {
          onlineStatusText = 'онлайн';
        } else {
          // Check last seen
          final lastSeenMap = ref.watch(lastSeenMapProvider);
          final lastSeenAt = lastSeenMap[otherUserId];
          
          if (lastSeenAt != null) {
            final now = DateTime.now();
            final diff = now.difference(lastSeenAt);
            
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
          const ConnectionStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // For group chats, open group settings screen
              if (currentChat.type == ChatType.group) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(chatId: widget.chatId),
                  ),
                );
              }
              // For private chats, could show user profile in the future
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/chat_background.png'),
            fit: BoxFit.cover,
            opacity: 0.3, // Subtle background, not too distracting
          ),
        ),
        child: Column(
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
                            final isHighlighted = message.id == _highlightedMessageId;
                            return MessageBubble(
                              message: message,
                              isHighlighted: isHighlighted,
                            );
                          },
                        ),
            ),
            // Typing indicator
            _buildTypingIndicator(),
            MessageInput(
            chatId: widget.chatId,
            isSending: messagesState.isSending,
            onSendMessage: (content) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendMessage(content);
              // Scroll to bottom after sending message
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _scrollToBottom();
              });
            },
            onSendAudio: (audioPath) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendAudioMessage(audioPath);
              // Scroll to bottom after sending audio
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _scrollToBottom();
              });
            },
            onSendImage: (imagePath) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendImageMessage(imagePath);
              // Scroll to bottom after sending image
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _scrollToBottom();
              });
            },
          ),
          ],
        ),
          ),
          // Scroll to bottom FAB
          Positioned(
            bottom: 100,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showScrollToBottomButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedScale(
                scale: _showScrollToBottomButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  onPressed: _showScrollToBottomButton ? _scrollToBottom : null,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


