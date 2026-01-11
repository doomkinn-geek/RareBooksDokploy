import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/messages_provider.dart';
import '../providers/signalr_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/contacts_names_provider.dart';
import '../providers/typing_provider.dart';
import '../providers/online_status_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/themes/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/connection_status_indicator.dart';
import '../widgets/typing_animation.dart';
import '../widgets/date_separator.dart';
import '../widgets/swipeable_message.dart';
import '../widgets/chat_background.dart';
import '../widgets/message_selection_app_bar.dart';
import '../../core/services/share_send_service.dart';
import 'group_settings_screen.dart';
import 'user_profile_screen.dart';
import 'forward_message_screen.dart';
import 'message_info_screen.dart';
import 'package:flutter/services.dart';

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
  List<Message> _currentMessages = []; // Cache messages for scroll calculations
  Timer? _markAsReadDebounce; // Debounce timer for mark as read
  
  // Reply mode state
  Message? _replyToMessage;
  
  // Edit mode state
  Message? _editingMessage;
  final TextEditingController _editController = TextEditingController();
  
  // Selection mode state (Telegram-style multi-select)
  final Set<String> _selectedMessageIds = {};
  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;
  
  /// Get selected messages
  List<Message> get _selectedMessages {
    final messages = ref.read(messagesProvider(widget.chatId)).messages;
    return messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
  }

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
    
    // Calculate the visible date based on scroll position
    final newDate = _calculateVisibleDate(currentScroll);
    
    // Update state if header visibility or date changed
    final dateChanged = newDate != null && 
        (_currentVisibleDate == null || !MessageDateUtils.isSameDay(_currentVisibleDate!, newDate));
    
    if (shouldShow != _showStickyDateHeader || dateChanged) {
      setState(() {
        _showStickyDateHeader = shouldShow;
        if (newDate != null) {
          _currentVisibleDate = newDate;
        }
      });
    }
  }
  
  /// Calculate the date of the topmost visible message based on scroll position
  DateTime? _calculateVisibleDate(double scrollPosition) {
    if (_currentMessages.isEmpty) return null;
    
    // With reverse: true ListView:
    // - scrollPosition = 0 means we're at the bottom (newest messages)
    // - scrollPosition increases as we scroll UP (toward older messages)
    // - Messages are sorted oldest first in _currentMessages
    
    // Approximate the item height (messages + some date separators)
    // We use a conservative estimate since items have varying heights
    const approximateItemHeight = 70.0;
    
    // Calculate how many items from the bottom (newest) we've scrolled
    final itemsFromBottom = (scrollPosition / approximateItemHeight).floor();
    
    // The visible message index counting from the end (newest)
    // _currentMessages is sorted oldest->newest, so we need to find the message
    // that corresponds to this scroll position
    final visibleIndexFromNewest = itemsFromBottom;
    final visibleIndex = _currentMessages.length - 1 - visibleIndexFromNewest;
    
    // Clamp to valid range
    final clampedIndex = visibleIndex.clamp(0, _currentMessages.length - 1);
    
    return _currentMessages[clampedIndex].createdAt;
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
      
      // STEP 5: Wait for messages to load before marking as read
      // IMPORTANT: Only mark as read if user actively opened the chat
      // Do NOT mark as read if this is just a push notification tap
      // The chat is "active" when the widget is mounted and visible
      int waitAttempts = 0;
      while (ref.read(messagesProvider(widget.chatId)).isLoading && waitAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitAttempts++;
      }
      
      // Wait a bit more to ensure messages are rendered on screen
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Check if user is still in the chat and at the bottom (seeing the messages)
      if (mounted && _scrollController.hasClients) {
        final scrollPos = _scrollController.position.pixels;
        final isAtBottom = scrollPos <= 100; // At or near bottom
        
        print('[CHAT_SCREEN] Scroll check: position=$scrollPos, isAtBottom=$isAtBottom');
        
        if (isAtBottom) {
          print('[CHAT_SCREEN] User at bottom of chat, marking messages as read (debounced)...');
          // Debounce: only mark as read if user stays at bottom for 300ms
          _markAsReadDebounce?.cancel();
          _markAsReadDebounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
            }
          });
        } else {
          print('[CHAT_SCREEN] User not at bottom (scrollPos=$scrollPos), NOT marking messages as read yet');
        }
      } else {
        print('[CHAT_SCREEN] Cannot check scroll position: mounted=$mounted, hasClients=${_scrollController.hasClients}');
      }
    
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
    
    // Only mark as read if user is at the bottom AND the chat is active (mounted)
    if (currentScroll <= threshold && mounted) {
      // User is at the bottom (newest messages), debounce mark as read
      print('[CHAT_SCREEN] User scrolled to bottom (pixels=$currentScroll), marking messages as read (debounced)');
      _markAsReadDebounce?.cancel();
      _markAsReadDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          ref.read(messagesProvider(widget.chatId).notifier).markMessagesAsRead();
        }
      });
    } else if (currentScroll > threshold) {
      print('[CHAT_SCREEN] User not at bottom (pixels=$currentScroll), skipping mark as read');
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
    // Clear notification context
    try {
      ref.read(notificationServiceProvider).setCurrentChat(null);
      ref.read(fcmServiceProvider).setCurrentChat(null);
    } catch (e) {
      print('[CHAT_SCREEN] Failed to clear notification context: $e');
    }
    
    // Clear local unread count immediately before dispose
    // Note: The actual refresh from server happens in main_screen.dart after navigation returns
    try {
      ref.read(chatsProvider.notifier).clearUnreadCount(widget.chatId);
      } catch (e) {
      print('[CHAT_SCREEN] Failed to clear unread count: $e');
      }
    
    // Cancel debounce timer
    _markAsReadDebounce?.cancel();
    
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
  
  /// Set message to reply to
  void _setReplyToMessage(Message message) {
    setState(() {
      _replyToMessage = message;
      _editingMessage = null; // Cancel editing if active
    });
  }
  
  /// Cancel reply mode
  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }
  
  /// Start editing a message
  void _startEditing(Message message) {
    setState(() {
      _editingMessage = message;
      _editController.text = message.content ?? '';
      _replyToMessage = null; // Cancel reply if active
    });
  }
  
  /// Cancel editing mode
  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _editController.clear();
    });
  }
  
  // ==================== SELECTION MODE ====================
  
  /// Toggle message selection
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }
  
  /// Start selection mode with a message
  void _startSelectionMode(String messageId) {
    setState(() {
      _selectedMessageIds.clear();
      _selectedMessageIds.add(messageId);
    });
  }
  
  /// Clear selection and exit selection mode
  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }
  
  /// Handle copy action for selected messages
  void _handleSelectionCopy() {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    
    // Collect text content from all selected messages
    final textContent = selected
        .where((m) => m.type == MessageType.text && m.content != null)
        .map((m) => m.content!)
        .join('\n\n');
    
    if (textContent.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textContent));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Скопировано'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    _clearSelection();
  }
  
  /// Handle forward action for selected messages
  Future<void> _handleSelectionForward() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    
    // For now, forward only the first message (multi-forward can be added later)
    final targetChatId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => ForwardMessageScreen(message: selected.first),
      ),
    );
    
    if (targetChatId != null) {
      for (final message in selected) {
        await ref.read(messagesProvider(targetChatId).notifier).forwardMessage(
          originalMessage: message,
          targetChatId: targetChatId,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переслано ${selected.length} сообщение(й)')),
        );
      }
    }
    
    _clearSelection();
  }
  
  /// Handle delete action for selected messages
  Future<void> _handleSelectionDelete() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить ${selected.length} сообщение(й)?'),
        content: const Text('Сообщения будут удалены безвозвратно.'),
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
    
    if (confirmed == true) {
      for (final message in selected) {
        await ref.read(messagesProvider(widget.chatId).notifier).deleteMessage(message.id);
      }
    }
    
    _clearSelection();
  }
  
  /// Handle share action for selected messages
  Future<void> _handleSelectionShare() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    
    try {
      final shareSendService = ref.read(shareSendServiceProvider);
      await shareSendService.shareMessages(selected);
    } catch (e) {
      print('[ChatScreen] Error sharing messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    _clearSelection();
  }
  
  /// Handle reply action for single selected message
  void _handleSelectionReply() {
    final selected = _selectedMessages;
    if (selected.length != 1) return;
    
    _setReplyToMessage(selected.first);
    _clearSelection();
  }
  
  /// Handle edit action for single selected message
  void _handleSelectionEdit() {
    final selected = _selectedMessages;
    if (selected.length != 1) return;
    
    _startEditing(selected.first);
    _clearSelection();
  }
  
  /// Handle info action for single selected message
  void _handleSelectionInfo() {
    final selected = _selectedMessages;
    if (selected.length != 1) return;
    
    final currentChat = ref.read(chatsProvider).chats.where((c) => c.id == widget.chatId).firstOrNull;
    if (currentChat != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MessageInfoScreen(
            message: selected.first,
            chatTitle: currentChat.title,
          ),
        ),
      );
    }
    _clearSelection();
  }
  
  // ==================== END SELECTION MODE ====================
  
  /// Navigate to a replied message
  void _navigateToMessage(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });
    
    final messages = ref.read(messagesProvider(widget.chatId)).messages;
    _scrollToHighlightedMessage(messages);
    
    // Clear highlight after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }
  
  /// Build messages list with date separators using reverse: true for performance
  /// With reverse: true, newest messages are at the bottom (index 0) and render first
  Widget _buildMessagesList(MessagesState messagesState) {
    final messages = messagesState.messages;
    
    // Cache messages for scroll calculations
    _currentMessages = messages;
    
    // Initialize the visible date with the newest message date on first build
    if (_currentVisibleDate == null && messages.isNotEmpty) {
      _currentVisibleDate = messages.last.createdAt;
    }
    
    // Build list of all image messages for horizontal swiping in viewer
    final allImageMessages = messages
        .where((m) => m.type == MessageType.image)
        .toList();
    
    // Create a map for quick lookup of image index by message id
    final imageIndexMap = <String, int>{};
    for (int i = 0; i < allImageMessages.length; i++) {
      imageIndexMap[allImageMessages[i].id] = i;
    }
    
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
          
          final isSelected = _selectedMessageIds.contains(item.id);
          
          return SwipeableMessage(
            message: item,
            onSwipeReply: _isSelectionMode ? null : () => _setReplyToMessage(item),
            child: GestureDetector(
              onTap: _isSelectionMode 
                  ? () => _toggleMessageSelection(item.id)
                  : null,
              onLongPressStart: (details) {
                if (_isSelectionMode) {
                  // In selection mode, toggle selection
                  _toggleMessageSelection(item.id);
                } else {
                  // Start selection mode instead of showing context menu
                  _startSelectionMode(item.id);
                }
              },
              child: Container(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleMessageSelection(item.id),
                          shape: const CircleBorder(),
                        ),
                      ),
                    // Message bubble
                    Expanded(
                      child: MessageBubble(
                        key: ValueKey('${stableKey}_${item.status.name}_$isSelected'),
                        message: item,
                        isHighlighted: isHighlighted,
                        onReplyTap: _isSelectionMode ? null : _navigateToMessage,
                        allImageMessages: item.type == MessageType.image ? allImageMessages : null,
                        imageIndex: item.type == MessageType.image ? (imageIndexMap[item.id] ?? 0) : 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        return const SizedBox.shrink();
      },
    );
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

    // Check selection mode capabilities
    final selectedMessages = _selectedMessages;
    final profileState = ref.read(profileProvider);
    final currentUserId = profileState.profile?.id;
    
    // Can edit: single message, own, text, not deleted
    final canEdit = selectedMessages.length == 1 &&
        selectedMessages.first.type == MessageType.text &&
        !selectedMessages.first.isDeleted &&
        (currentUserId != null && selectedMessages.first.senderId == currentUserId);
    
    // Can copy: all selected are text messages
    final canCopy = selectedMessages.isNotEmpty &&
        selectedMessages.every((m) => m.type == MessageType.text && m.content != null);
    
    // Can show info: single message, own, in group chat
    final canShowInfo = selectedMessages.length == 1 &&
        currentChat.type == ChatType.group &&
        (currentUserId != null && selectedMessages.first.senderId == currentUserId) &&
        !selectedMessages.first.isLocalOnly;
    
    // Can delete: all selected are own messages
    final canDelete = selectedMessages.isNotEmpty &&
        selectedMessages.every((m) => 
          (currentUserId != null && m.senderId == currentUserId) || m.isLocalOnly);
    
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
      appBar: _isSelectionMode
          ? MessageSelectionAppBar(
              selectedCount: _selectedMessageIds.length,
              canEdit: canEdit,
              canCopy: canCopy,
              canShowInfo: canShowInfo,
              canDelete: canDelete,
              onClose: _clearSelection,
              onCopy: _handleSelectionCopy,
              onForward: _handleSelectionForward,
              onShare: _handleSelectionShare,
              onDelete: _handleSelectionDelete,
              onEdit: canEdit ? _handleSelectionEdit : null,
              onInfo: canShowInfo ? _handleSelectionInfo : null,
              onReply: selectedMessages.length == 1 ? _handleSelectionReply : null,
            )
          : AppBar(
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
                        ? AppColors.onlineIndicator 
                        : Colors.white70,
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
          ChatBackground(
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
            replyToMessage: _replyToMessage,
            onCancelReply: _cancelReply,
            editingMessage: _editingMessage,
            onCancelEdit: _cancelEditing,
            onSaveEdit: (messageId, newContent) {
              ref.read(messagesProvider(widget.chatId).notifier)
                  .editMessage(messageId, newContent);
              _cancelEditing();
            },
            onSendMessage: (content) {
              if (_replyToMessage != null) {
                // Send with reply
                ref
                    .read(messagesProvider(widget.chatId).notifier)
                    .sendMessageWithReply(content, _replyToMessage!);
                _cancelReply();
              } else if (_editingMessage != null) {
                // Save edit
                ref.read(messagesProvider(widget.chatId).notifier)
                    .editMessage(_editingMessage!.id, content);
                _cancelEditing();
              } else {
                // Normal send
                ref
                    .read(messagesProvider(widget.chatId).notifier)
                    .sendMessage(content);
              }
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
            onSendFile: (filePath, fileName) {
              ref
                  .read(messagesProvider(widget.chatId).notifier)
                  .sendFileMessage(filePath, fileName);
              // Scroll to bottom after sending file
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
    ),
    );
  }
}


