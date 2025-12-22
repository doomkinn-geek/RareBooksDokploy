import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../data/models/message_model.dart';
import '../../data/models/chat_model.dart';
import 'chats_provider.dart';

final chatPreviewSyncServiceProvider = Provider<ChatPreviewSyncService>((ref) {
  return ChatPreviewSyncService(ref);
});

class ChatPreviewUpdate {
  final String chatId;
  final Message? lastMessage;
  final int? unreadCountDelta; // +1, -1, or null
  final DateTime timestamp;
  
  ChatPreviewUpdate({
    required this.chatId,
    this.lastMessage,
    this.unreadCountDelta,
    required this.timestamp,
  });
}

class ChatPreviewSyncService {
  final Ref _ref;
  final List<ChatPreviewUpdate> _pendingUpdates = [];
  Timer? _processTimer;
  
  ChatPreviewSyncService(this._ref) {
    _startProcessingLoop();
  }
  
  void enqueueUpdate(ChatPreviewUpdate update) {
    _pendingUpdates.add(update);
    print('[ChatPreviewSync] Enqueued update for chat ${update.chatId}');
  }
  
  void _startProcessingLoop() {
    _processTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processPendingUpdates();
    });
  }
  
  void _processPendingUpdates() {
    if (_pendingUpdates.isEmpty) return;
    
    print('[ChatPreviewSync] Processing ${_pendingUpdates.length} pending updates');
    
    // Group by chatId and merge updates
    final updatesByChat = <String, ChatPreviewUpdate>{};
    
    for (final update in _pendingUpdates) {
      final existing = updatesByChat[update.chatId];
      
      if (existing == null) {
        updatesByChat[update.chatId] = update;
      } else {
        // Merge updates: keep latest lastMessage, sum unreadCountDelta
        updatesByChat[update.chatId] = ChatPreviewUpdate(
          chatId: update.chatId,
          lastMessage: update.lastMessage ?? existing.lastMessage,
          unreadCountDelta: (existing.unreadCountDelta ?? 0) + (update.unreadCountDelta ?? 0),
          timestamp: update.timestamp.isAfter(existing.timestamp) 
              ? update.timestamp 
              : existing.timestamp,
        );
      }
    }
    
    // Apply all updates
    for (final update in updatesByChat.values) {
      _applyUpdate(update);
    }
    
    _pendingUpdates.clear();
  }
  
  void _applyUpdate(ChatPreviewUpdate update) {
    try {
      final chatsNotifier = _ref.read(chatsProvider.notifier);
      
      if (update.lastMessage != null) {
        // Update last message
        final incrementUnread = update.unreadCountDelta != null && update.unreadCountDelta! > 0;
        chatsNotifier.updateChatLastMessage(
          update.chatId,
          update.lastMessage!,
          incrementUnread: incrementUnread,
        );
      } else if (update.unreadCountDelta != null) {
        // Only update unread count
        _adjustUnreadCount(update.chatId, update.unreadCountDelta!);
      }
      
      print('[ChatPreviewSync] Applied update for chat ${update.chatId}');
    } catch (e) {
      print('[ChatPreviewSync] Failed to apply update: $e');
    }
  }
  
  void _adjustUnreadCount(String chatId, int delta) {
    final chatsNotifier = _ref.read(chatsProvider.notifier);
    final chatsState = _ref.read(chatsProvider);
    
    final index = chatsState.chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;
    
    final chat = chatsState.chats[index];
    final newUnreadCount = (chat.unreadCount + delta).clamp(0, 999999);
    
    final updatedChat = Chat(
      id: chat.id,
      type: chat.type,
      title: chat.title,
      avatar: chat.avatar,
      lastMessage: chat.lastMessage,
      unreadCount: newUnreadCount,
      createdAt: chat.createdAt,
      otherParticipantId: chat.otherParticipantId,
    );
    
    chatsNotifier.updateChat(updatedChat);
  }
  
  void dispose() {
    _processTimer?.cancel();
  }
}

