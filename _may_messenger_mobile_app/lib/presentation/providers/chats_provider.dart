import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import 'auth_provider.dart';

final chatsProvider = StateNotifierProvider<ChatsNotifier, ChatsState>((ref) {
  return ChatsNotifier(ref.read(chatRepositoryProvider));
});

class ChatsState {
  final List<Chat> chats;
  final bool isLoading;
  final String? error;

  ChatsState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  ChatsState copyWith({
    List<Chat>? chats,
    bool? isLoading,
    String? error,
  }) {
    return ChatsState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<Chat> get groupChats => chats.where((c) => c.type == ChatType.group).toList();
  List<Chat> get privateChats => chats.where((c) => c.type == ChatType.private).toList();
}

class ChatsNotifier extends StateNotifier<ChatsState> {
  final dynamic _chatRepository;

  ChatsNotifier(this._chatRepository) : super(ChatsState()) {
    // НЕ загружаем чаты автоматически - они будут загружены MainScreen
    // после того, как токен будет восстановлен
  }

  Future<void> loadChats({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final chats = await _chatRepository.getChats(forceRefresh: forceRefresh);
      
      state = state.copyWith(
        chats: chats,
        isLoading: false,
      );
    } catch (e) {
      final userFriendlyError = formatUserFriendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: userFriendlyError,
      );
    }
  }

  Future<Chat?> createChat({
    String? title,
    required List<String> participantIds,
  }) async {
    try {
      final chat = await _chatRepository.createChat(
        title: title ?? '',
        participantIds: participantIds,
      );
      await loadChats(forceRefresh: true);
      return chat;
    } catch (e) {
      state = state.copyWith(error: formatUserFriendlyError(e));
      return null;
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _chatRepository.deleteChat(chatId);
      // Chat will be removed from state via SignalR notification
    } catch (e) {
      print('[ChatsProvider] Failed to delete chat: $e');
      state = state.copyWith(error: formatUserFriendlyError(e));
      rethrow;
    }
  }

  void removeChat(String chatId) {
    final updatedChats = state.chats.where((c) => c.id != chatId).toList();
    state = state.copyWith(chats: updatedChats);
  }

  void addChat(Chat chat) {
    final exists = state.chats.any((c) => c.id == chat.id);
    if (!exists) {
      state = state.copyWith(chats: [chat, ...state.chats]);
    }
  }

  void updateChat(Chat updatedChat) {
    final index = state.chats.indexWhere((c) => c.id == updatedChat.id);
    if (index != -1) {
      final updatedChats = [...state.chats];
      updatedChats[index] = updatedChat;
      state = state.copyWith(chats: updatedChats);
    }
  }

  void updateChatLastMessage(String chatId, Message message, {bool incrementUnread = false}) {
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = state.chats[index];
      final newUnreadCount = incrementUnread ? chat.unreadCount + 1 : chat.unreadCount;
      
      final updatedChat = Chat(
        id: chat.id,
        type: chat.type,
        title: chat.title,
        avatar: chat.avatar,
        lastMessage: message,
        unreadCount: newUnreadCount,
        createdAt: chat.createdAt,
        otherParticipantId: chat.otherParticipantId,
      );
      
      final updatedChats = [...state.chats];
      updatedChats[index] = updatedChat;
      
      // Сортируем чаты по времени последнего сообщения (новые вверху)
      updatedChats.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      
      state = state.copyWith(chats: updatedChats);
      
      // Сохраняем в кэш
      try {
        _chatRepository.updateChatLastMessageInCache(chatId, message);
      } catch (e) {
        print('[ChatsProvider] Failed to update last message in cache: $e');
      }
    }
  }

  void clearUnreadCount(String chatId) {
    final index = state.chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = state.chats[index];
      if (chat.unreadCount > 0) {
        final updatedChat = Chat(
          id: chat.id,
          type: chat.type,
          title: chat.title,
          avatar: chat.avatar,
          lastMessage: chat.lastMessage,
          unreadCount: 0,
          createdAt: chat.createdAt,
          otherParticipantId: chat.otherParticipantId,
        );
        
        final updatedChats = [...state.chats];
        updatedChats[index] = updatedChat;
        state = state.copyWith(chats: updatedChats);
        
        print('[ChatsProvider] Cleared unread count for chat $chatId');
      }
    }
  }
}


