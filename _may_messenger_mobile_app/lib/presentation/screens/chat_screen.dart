import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart' show navigatorKey;
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
import '../widgets/date_separator.dart';
import 'group_settings_screen.dart';
import 'user_profile_screen.dart';

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
  DateTime? _currentVisibleDate; // For sticky date header
  bool _showStickyDateHeader = false; // Show/hide sticky date header

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
    // and to show/hide scroll-to-bottom FAB and sticky date header
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_updateScrollToBottomButton);
    _scrollController.addListener(_onScrollForPagination);
    _scrollController.addListener(_updateStickyDateHeader);
    
    // CRITICAL: Perform reliable sync when opening chat
    // This ensures we have the latest data even after push notification
    _performReliableChatSync();
  }
  
  /// Scroll listener for loading older messages when near top
  /// With reverse: true ListView, "top" in user terms is maxScrollExtent
  void _onScrollForPagination() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 200.0; // Start loading when within 200px of top (oldest messages)
    
    // With reverse: true, scrolling UP (toward older messages) increases pixels toward maxScrollExtent
    if (maxScroll - currentScroll < threshold) {
      // Near top (oldest messages), load older messages
      final messagesState = ref.read(messagesProvider(widget.chatId));
      if (!messagesState.isLoadingOlder && messagesState.hasMoreOlder) {
        print('[CHAT_SCREEN] Near top (oldest), loading older messages...');
        ref.read(messagesProvider(widget.chatId).notifier).loadOlderMessages();
      }
    }
  }
  
  /// Update sticky date header based on currently visible messages
  void _updateStickyDateHeader() {
    if (!_scrollController.hasClients) return;
    
    // Show sticky header only when scrolled (not at bottom/newest messages)
    final currentScroll = _scrollController.position.pixels;
    final shouldShow = currentScroll > 50; // Show when scrolled more than 50px from newest
    
    if (shouldShow != _showStickyDateHeader) {
      setState(() {
        _showStickyDateHeader = shouldShow;
      });
    }
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
    
    // With reverse: true, "bottom" (newest messages) is at pixels = 0
    final currentScroll = _scrollController.position.pixels;
    final threshold = 100.0; // pixels from bottom (newest)
    
    if (currentScroll <= threshold) {
      // User is at the bottom (newest messages), mark messages as read
      ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
    }
  }

  void _updateScrollToBottomButton() {
    if (!_scrollController.hasClients) return;
    
    // With reverse: true, "bottom" (newest) is at pixels = 0
    final currentScroll = _scrollController.position.pixels;
    final threshold = 500.0; // Show FAB when scrolled up more than 500px from bottom
    
    final shouldShow = currentScroll > threshold;
    if (shouldShow != _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = shouldShow;
      });
    }
  }

  /// Check if user is near bottom of the list (for auto-scroll on new message)
  /// With reverse: true, bottom is at pixels = 0
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    
    final currentScroll = _scrollController.position.pixels;
    final threshold = 150.0; // Consider "near bottom" if within 150px
    
    return currentScroll <= threshold;
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
    // IMPORTANT: Clear unread count BEFORE widget is disposed
    // Use WidgetsBinding to execute after current frame but before provider is disposed
    final chatId = widget.chatId;
    
    // Clear notification context
    try {
      ref.read(notificationServiceProvider).setCurrentChat(null);
      ref.read(fcmServiceProvider).setCurrentChat(null);
    } catch (e) {
      print('[CHAT_SCREEN] Failed to clear notification context: $e');
    }
    
    // Clear unread count - schedule for after dispose to ensure state update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Force refresh the chat list to get accurate unread counts from server
        final container = ProviderScope.containerOf(navigatorKey.currentContext!);
        container.read(chatsProvider.notifier).clearUnreadCount(chatId);
        
        // Also trigger a background refresh to sync with server
        container.read(chatsProvider.notifier).loadChats(forceRefresh: true);
      } catch (e) {
        print('[CHAT_SCREEN] Failed to clear unread count on dispose: $e');
      }
    });
    
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
    // Get contact names from phone book
    final contactNames = ref.read(contactsNamesProvider);
    
    // Helper to get display name (from phone book or fallback to server name)
    String getDisplayName(TypingUser user) {
      return contactNames[user.userId] ?? user.userName;
    }
    
    // Helper to get activity text based on activity type
    String getActivityText(TypingUser user, bool isPlural) {
      if (user.activityType == ActivityType.recordingAudio) {
        return isPlural ? 'записывают аудио...' : 'записывает аудио...';
      }
      return isPlural ? 'пишут...' : 'пишет...';
    }
    
    if (users.length == 1) {
      return '${getDisplayName(users[0])} ${getActivityText(users[0], false)}';
    } else if (users.length == 2) {
      // Check if both have same activity type
      final sameActivity = users[0].activityType == users[1].activityType;
      if (sameActivity) {
        return '${getDisplayName(users[0])} и ${getDisplayName(users[1])} ${getActivityText(users[0], true)}';
      }
      return '${getDisplayName(users[0])} и ${getDisplayName(users[1])} активны...';
    } else {
      return '${getDisplayName(users[0])} и еще ${users.length - 1} активны...';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // With reverse: true, bottom (newest messages) is at 0
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToHighlightedMessage(List<Message> messages) {
    if (!_scrollController.hasClients || _highlightedMessageId == null) return;
    
    final index = messages.indexWhere((m) => m.id == _highlightedMessageId);
    if (index == -1) {
      // Message not found, scroll to bottom (newest)
      _scrollToBottom();
      return;
    }
    
    // With reverse: true, we need to calculate from the end
    // Index 0 is the oldest, last index is newest (at bottom/0 scroll position)
    final distanceFromNewest = messages.length - 1 - index;
    final approximateItemHeight = 100.0;
    final scrollPosition = distanceFromNewest * approximateItemHeight;
    
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
  
  /// Build messages list with date separators using reverse: true for performance
  /// With reverse: true, newest messages are at the bottom (index 0) and render first
  Widget _buildMessagesList(MessagesState messagesState) {
    final messages = messagesState.messages;
    
    // Build items list with date separators (in normal order, oldest first)
    // We'll reverse the display order in ListView
    final List<dynamic> items = []; // Either Message or DateTime for separator
    
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      
      // Check if we need a date separator before this message
      if (i == 0) {
        // First (oldest) message always gets a separator
        items.add(message.createdAt);
      } else {
        final prevMessage = messages[i - 1];
        if (!MessageDateUtils.isSameDay(message.createdAt, prevMessage.createdAt)) {
          // Different day, add separator
          items.add(message.createdAt);
        }
      }
      
      // Add the message
      items.add(message);
    }
    
    // With reverse: true, we need to reverse our items so newest is at index 0
    final reversedItems = items.reversed.toList();
    final itemCount = reversedItems.length + (messagesState.isLoadingOlder ? 1 : 0);
    
    // Update current visible date for sticky header
    _updateVisibleDate(messages);
    
    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Newest messages at bottom, renders from newest
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Loading indicator for older messages (now at the END because of reverse)
        if (messagesState.isLoadingOlder && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        if (index >= reversedItems.length) {
          return const SizedBox.shrink();
        }
        
        final item = reversedItems[index];
        
        if (item is DateTime) {
          // It's a date separator
          return DateSeparator(date: item);
        } else if (item is Message) {
          // It's a message
          final isHighlighted = item.id == _highlightedMessageId;
          // Use localId if available (stable during sync), fallback to id
          // Include status in key to force rebuild when status changes
          final stableKey = item.localId ?? item.id;
          return MessageBubble(
            key: ValueKey('${stableKey}_${item.status.name}'),
            message: item,
            isHighlighted: isHighlighted,
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  /// Update the currently visible date for sticky header
  void _updateVisibleDate(List<Message> messages) {
    if (messages.isEmpty) return;
    
    // Estimate which message is currently visible based on scroll position
    if (!_scrollController.hasClients) {
      _currentVisibleDate = messages.last.createdAt;
      return;
    }
    
    final currentScroll = _scrollController.position.pixels;
    final approximateItemHeight = 80.0;
    
    // Calculate approximate visible message index (from newest)
    final visibleIndexFromNewest = (currentScroll / approximateItemHeight).floor();
    final visibleIndex = messages.length - 1 - visibleIndexFromNewest;
    
    if (visibleIndex >= 0 && visibleIndex < messages.length) {
      final newDate = messages[visibleIndex.clamp(0, messages.length - 1)].createdAt;
      if (_currentVisibleDate == null || 
          !MessageDateUtils.isSameDay(_currentVisibleDate!, newDate)) {
        _currentVisibleDate = newDate;
      }
    }
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

    // With reverse: true, newest messages are already at bottom (no scroll needed)
    // Only scroll if we have a highlighted message to navigate to
    if (!_hasInitialScrolled && 
        messagesState.messages.isNotEmpty && 
        !messagesState.isLoading) {
      _hasInitialScrolled = true;
      if (_highlightedMessageId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedMessage(messagesState.messages);
        });
      }
      // No need to scroll to bottom - reverse: true handles this automatically
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
        title: GestureDetector(
          onTap: () {
            // Navigate to profile on tap for private chats
            if (currentChat.type == ChatType.private && 
                currentChat.otherParticipantId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: currentChat.otherParticipantId!,
                    initialDisplayName: displayTitle,
                    initialAvatar: currentChat.otherParticipantAvatar,
                  ),
                ),
              );
            } else if (currentChat.type == ChatType.group) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GroupSettingsScreen(chatId: widget.chatId),
                ),
              );
            }
          },
          child: Column(
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
        ),
        actions: [
          const ConnectionStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              if (currentChat.type == ChatType.group) {
                // For group chats, open group settings screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(chatId: widget.chatId),
                  ),
                );
              } else if (currentChat.type == ChatType.private && 
                         currentChat.otherParticipantId != null) {
                // For private chats, open user profile screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(
                      userId: currentChat.otherParticipantId!,
                      initialDisplayName: displayTitle,
                      initialAvatar: currentChat.otherParticipantAvatar,
                    ),
                  ),
                );
              }
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
            fit: BoxFit.contain, // Вписываем изображение полностью с сохранением пропорций
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
                      : Stack(
                          children: [
                            _buildMessagesList(messagesState),
                            // Sticky date header
                            if (_showStickyDateHeader && _currentVisibleDate != null)
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: _showStickyDateHeader ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: DateSeparator(date: _currentVisibleDate!),
                                  ),
                                ),
                              ),
                          ],
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


