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
    // #region agent log
    await _logger.debug('messages_provider.sendMessage.entry', '[H3] sendMessage called', {'chatId': chatId, 'content': content.substring(0, content.length > 20 ? 20 : content.length)});
    // #endregion
    
    state = state.copyWith(isSending: true);
    try {
      await _messageRepository.sendMessage(
        chatId: chatId,
        type: MessageType.text,
        content: content,
      );
      
      // #region agent log
      await _logger.debug('messages_provider.sendMessage.sent', '[H3] Message sent via REST API', {'chatId': chatId});
      // #endregion
      
      // НЕ добавляем локально - сообщение придёт через SignalR
      state = state.copyWith(
        isSending: false,
      );
    } catch (e) {
      // #region agent log
      await _logger.error('messages_provider.sendMessage.error', '[H3] Failed to send message', {'error': e.toString()});
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
    // #region agent log
    _logger.debug('messages_provider.addMessage.entry', '[H1] addMessage called', {'messageId': message.id, 'chatId': message.chatId, 'currentChatId': chatId, 'currentCount': '${state.messages.length}'});
    // #endregion
    
    // Проверяем, что сообщение для этого чата
    if (message.chatId != chatId) {
      // #region agent log
      _logger.debug('messages_provider.addMessage.wrongChat', '[H1] Message for different chat, ignoring', {'messageId': message.id, 'messageChatId': message.chatId, 'currentChatId': chatId});
      // #endregion
      return;
    }
    
    // Проверяем, нет ли уже сообщения с таким ID
    final exists = state.messages.any((m) => m.id == message.id);
    
    // #region agent log
    _logger.debug('messages_provider.addMessage.check', '[H1] Duplicate check', {'messageId': message.id, 'exists': '$exists'});
    // #endregion
    
    if (!exists) {
      final newMessages = [...state.messages, message];
      state = state.copyWith(
        messages: newMessages,
      );
      
      // #region agent log
      _logger.debug('messages_provider.addMessage.added', '[H1] Message added', {'messageId': message.id, 'newCount': '${state.messages.length}'});
      // #endregion
    } else {
      // #region agent log
      _logger.debug('messages_provider.addMessage.duplicate', '[H1] Message already exists, ignoring', {'messageId': message.id});
      // #endregion
    }
  }
}


