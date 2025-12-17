import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart';
import '../../core/services/logger_service.dart';
import 'auth_provider.dart';
import 'signalr_provider.dart';
import 'profile_provider.dart';

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    // Keep the provider alive even when not used
    ref.keepAlive();
    return MessagesNotifier(
      ref.read(messageRepositoryProvider),
      chatId,
      ref.read(signalRServiceProvider),
      ref,
    );
  },
);

class MessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final dynamic _messageRepository;
  final String chatId;
  final dynamic _signalRService;
  final Ref _ref;
  final _logger = LoggerService();

  MessagesNotifier(
    this._messageRepository,
    this.chatId,
    this._signalRService,
    this._ref,
  ) : super(MessagesState()) {
    loadMessages();
  }

  Future<void> loadMessages({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      
      // Сортируем сообщения по дате создания (от старых к новым)
      // ListView без reverse отобразит старые вверху, новые внизу
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
      
      // Гарантируем сохранение в кэш (на случай если репозиторий не сохранил)
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        await localDataSource.cacheMessages(chatId, messages);
      } catch (e) {
        print('[MessagesProvider] Failed to cache messages: $e');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    state = state.copyWith(isSending: true);
    try {
      // Send via REST API and get the message back
      final message = await _messageRepository.sendMessage(
        chatId: chatId,
        type: MessageType.text,
        content: content,
      );
      
      // Add message locally immediately
      // If SignalR also sends it, addMessage() will ignore duplicate
      addMessage(message);
      
      state = state.copyWith(
        isSending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendAudioMessage(String audioPath) async {
    state = state.copyWith(isSending: true);
    try {
      // Send via REST API and get the message back
      final message = await _messageRepository.sendAudioMessage(
        chatId: chatId,
        audioPath: audioPath,
      );
      
      // Add message locally immediately
      // If SignalR also sends it, addMessage() will ignore duplicate
      addMessage(message);
      
      state = state.copyWith(
        isSending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void addMessage(Message message) {
    // Проверяем, что сообщение для этого чата
    if (message.chatId != chatId) {
      return;
    }
    
    // Проверяем, нет ли уже сообщения с таким ID
    final exists = state.messages.any((m) => m.id == message.id);
    
    if (!exists) {
      // Добавляем новое сообщение и сортируем по дате
      final newMessages = [...state.messages, message];
      // Сортируем по дате создания (от старых к новым)
      newMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        messages: newMessages,
      );
      
      // Сохраняем сообщение в кэш для персистентности
      try {
        final localDataSource = _ref.read(localDataSourceProvider);
        localDataSource.addMessageToCache(chatId, message);
      } catch (e) {
        print('[MessagesProvider] Failed to cache message: $e');
      }
      
      // Background download for audio messages
      if (message.type == MessageType.audio && 
          message.filePath != null && 
          message.filePath!.isNotEmpty) {
        _downloadAudioInBackground(message);
      }
    }
  }

  Future<void> _downloadAudioInBackground(Message message) async {
    try {
      final audioStorageService = _ref.read(audioStorageServiceProvider);
      final localDataSource = _ref.read(localDataSourceProvider);
      
      // Check if already downloaded
      final hasLocal = await audioStorageService.hasLocalAudio(message.id);
      if (hasLocal) return;
      
      // Download audio
      final audioUrl = '${message.filePath}';
      final localPath = await audioStorageService.saveAudioLocally(
        message.id,
        audioUrl.startsWith('http') ? audioUrl : 'https://messenger.rare-books.ru${audioUrl}'
      );
      
      if (localPath != null) {
        // Update cache
        await localDataSource.updateMessageLocalAudioPath(
          message.chatId,
          message.id,
          localPath
        );
        
        // Update message in state
        final messageIndex = state.messages.indexWhere((m) => m.id == message.id);
        if (messageIndex != -1) {
          final updatedMessages = [...state.messages];
          updatedMessages[messageIndex] = updatedMessages[messageIndex].copyWith(
            localAudioPath: localPath
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
    } catch (e) {
      // Silently fail - user can download on play
      print('[MessagesProvider] Background audio download failed: $e');
    }
  }

  void updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final updatedMessages = [...state.messages];
      final oldMessage = updatedMessages[messageIndex];
      updatedMessages[messageIndex] = oldMessage.copyWith(status: status);
      
      state = state.copyWith(messages: updatedMessages);
    }
  }

  Future<void> markMessagesAsRead() async {
    try {
      // Get current user ID
      final profileState = _ref.read(profileProvider);
      final currentUserId = profileState.profile?.id;
      
      if (currentUserId == null) return;
      
      // Find all unread messages from other users
      final unreadMessages = state.messages.where((message) {
        return message.senderId != currentUserId && 
               message.status != MessageStatus.read;
      }).toList();
      
      // Mark each message as read via SignalR
      for (final message in unreadMessages) {
        try {
          await _signalRService.markMessageAsRead(message.id, chatId);
        } catch (e) {
          print('Failed to mark message ${message.id} as read: $e');
        }
      }
    } catch (e) {
      print('Failed to mark messages as read: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _messageRepository.deleteMessage(messageId);
      // Message will be removed from state via SignalR notification
    } catch (e) {
      print('[MessagesProvider] Failed to delete message: $e');
      rethrow;
    }
  }

  void removeMessage(String messageId) {
    final updatedMessages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);
  }
}


