import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart';
import '../../core/services/logger_service.dart';
import 'auth_provider.dart';

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    // Keep the provider alive even when not used
    ref.keepAlive();
    return MessagesNotifier(ref.read(messageRepositoryProvider), chatId);
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
  final _logger = LoggerService();

  MessagesNotifier(this._messageRepository, this.chatId) : super(MessagesState()) {
    loadMessages();
  }

  Future<void> loadMessages({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _messageRepository.getMessages(
        chatId: chatId,
        forceRefresh: forceRefresh,
      );
      
      state = state.copyWith(
        messages: messages.reversed.toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    // #region agent log - HYPOTHESIS B
    await _logger.debug('messages_provider.sendMessage.entry', '[HYP-B] sendMessage called', {'chatId': chatId, 'content': content.substring(0, content.length > 20 ? 20 : content.length), 'currentMessageCount': '${state.messages.length}'});
    // #endregion
    
    state = state.copyWith(isSending: true);
    try {
      await _messageRepository.sendMessage(
        chatId: chatId,
        type: MessageType.text,
        content: content,
      );
      
      // #region agent log - HYPOTHESIS B
      await _logger.debug('messages_provider.sendMessage.sent', '[HYP-B] Message sent via REST API, waiting for SignalR', {'chatId': chatId});
      // #endregion
      
      // НЕ добавляем локально - сообщение придёт через SignalR
      state = state.copyWith(
        isSending: false,
      );
      
      // #region agent log - HYPOTHESIS B
      await _logger.debug('messages_provider.sendMessage.afterStateUpdate', '[HYP-B] State updated after send, messageCount still: ${state.messages.length}', {'chatId': chatId});
      // #endregion
    } catch (e) {
      // #region agent log
      await _logger.error('messages_provider.sendMessage.error', '[HYP-B] Failed to send message', {'error': e.toString()});
      // #endregion
      
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendAudioMessage(String audioPath) async {
    // #region agent log
    await _logger.debug('messages_provider.sendAudioMessage.entry', '[H4] sendAudioMessage called', {'chatId': chatId, 'audioPath': audioPath});
    // #endregion
    
    state = state.copyWith(isSending: true);
    try {
      await _messageRepository.sendAudioMessage(
        chatId: chatId,
        audioPath: audioPath,
      );
      
      // #region agent log
      await _logger.debug('messages_provider.sendAudioMessage.sent', '[H4] Audio message sent via REST API', {'chatId': chatId});
      // #endregion
      
      // НЕ добавляем локально - сообщение придёт через SignalR
      state = state.copyWith(
        isSending: false,
      );
    } catch (e) {
      // #region agent log
      await _logger.error('messages_provider.sendAudioMessage.error', '[H4] Failed to send audio message', {'error': e.toString(), 'audioPath': audioPath});
      // #endregion
      
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void addMessage(Message message) {
    // #region agent log - HYPOTHESIS D
    _logger.debug('messages_provider.addMessage.entry', '[HYP-D] addMessage called', {
      'messageId': message.id, 
      'chatId': message.chatId, 
      'currentChatId': chatId, 
      'currentCount': '${state.messages.length}',
      'senderId': message.senderId,
      'timestamp': DateTime.now().toIso8601String()
    });
    // #endregion
    
    // Проверяем, что сообщение для этого чата
    if (message.chatId != chatId) {
      // #region agent log - HYPOTHESIS D
      _logger.debug('messages_provider.addMessage.wrongChat', '[HYP-D] Message for different chat, ignoring', {'messageId': message.id, 'messageChatId': message.chatId, 'currentChatId': chatId});
      // #endregion
      return;
    }
    
    // Проверяем, нет ли уже сообщения с таким ID
    final exists = state.messages.any((m) => m.id == message.id);
    
    // #region agent log - HYPOTHESIS D
    _logger.debug('messages_provider.addMessage.check', '[HYP-D] Duplicate check', {'messageId': message.id, 'exists': '$exists', 'existingIds': state.messages.map((m) => m.id).join(',')});
    // #endregion
    
    if (!exists) {
      final newMessages = [...state.messages, message];
      state = state.copyWith(
        messages: newMessages,
      );
      
      // #region agent log - HYPOTHESIS D
      _logger.debug('messages_provider.addMessage.added', '[HYP-D] Message added to state', {
        'messageId': message.id, 
        'newCount': '${state.messages.length}',
        'allIds': state.messages.map((m) => m.id).join(',')
      });
      // #endregion
    } else {
      // #region agent log - HYPOTHESIS D
      _logger.debug('messages_provider.addMessage.duplicate', '[HYP-D] Message already exists, ignoring', {'messageId': message.id});
      // #endregion
    }
  }

  void updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final updatedMessages = [...state.messages];
      final oldMessage = updatedMessages[messageIndex];
      updatedMessages[messageIndex] = Message(
        id: oldMessage.id,
        chatId: oldMessage.chatId,
        senderId: oldMessage.senderId,
        senderName: oldMessage.senderName,
        type: oldMessage.type,
        content: oldMessage.content,
        filePath: oldMessage.filePath,
        status: status,
        createdAt: oldMessage.createdAt,
      );
      
      state = state.copyWith(messages: updatedMessages);
    }
  }
}


