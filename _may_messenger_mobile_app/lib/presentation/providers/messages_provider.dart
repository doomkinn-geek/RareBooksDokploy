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
      final newMessages = [...state.messages, message];
      state = state.copyWith(
        messages: newMessages,
      );
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


