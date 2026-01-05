import '../datasources/api_datasource.dart';
import '../datasources/local_datasource.dart';
import '../models/message_model.dart';

class MessageRepository {
  final ApiDataSource _apiDataSource;
  final LocalDataSource _localDataSource;

  MessageRepository(this._apiDataSource, this._localDataSource);

  Future<List<Message>> getMessages({
    required String chatId,
    int skip = 0,
    int take = 200,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && skip == 0) {
      final cachedMessages = await _localDataSource.getCachedMessages(chatId);
      
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        return cachedMessages;
      }
    }

    final messages = await _apiDataSource.getMessages(
      chatId: chatId,
      skip: skip,
      take: take,
    );

    if (skip == 0) {
      await _localDataSource.cacheMessages(chatId, messages);
    }

    return messages;
  }

  Future<Message> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
    String? clientMessageId,
    String? replyToMessageId,
    bool isEncrypted = false,
  }) async {
    return await _apiDataSource.sendMessage(
      chatId: chatId,
      type: type,
      content: content,
      clientMessageId: clientMessageId,
      replyToMessageId: replyToMessageId,
      isEncrypted: isEncrypted,
    );
  }

  Future<Message> sendAudioMessage({
    required String chatId,
    required String audioPath,
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    return await _apiDataSource.sendAudioMessage(
      chatId: chatId,
      audioPath: audioPath,
      clientMessageId: clientMessageId,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<Message> sendImageMessage({
    required String chatId,
    required String imagePath,
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    return await _apiDataSource.sendImageMessage(
      chatId: chatId,
      imagePath: imagePath,
      clientMessageId: clientMessageId,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<Message> sendFileMessage({
    required String chatId,
    required String filePath,
    required String fileName,
    String? clientMessageId,
    String? replyToMessageId,
  }) async {
    return await _apiDataSource.sendFileMessage(
      chatId: chatId,
      filePath: filePath,
      fileName: fileName,
      clientMessageId: clientMessageId,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _apiDataSource.deleteMessage(messageId);
    // Note: Local cache will be updated via SignalR notification
  }

  /// Get unsynced messages since a specific timestamp (for incremental sync)
  Future<List<Message>> getUnsyncedMessages({
    required DateTime since,
    int take = 100,
  }) async {
    try {
      return await _apiDataSource.getUnsyncedMessages(
        since: since,
        take: take,
      );
    } catch (e) {
      print('[MessageRepository] Failed to get unsynced messages: $e');
      rethrow;
    }
  }

  /// Get a specific message by ID (for recovery after push notification)
  Future<Message> getMessageById(String messageId) async {
    try {
      return await _apiDataSource.getMessageById(messageId);
    } catch (e) {
      print('[MessageRepository] Failed to get message by ID: $e');
      rethrow;
    }
  }

  Future<void> batchMarkAsRead(List<String> messageIds) async {
    await _apiDataSource.batchMarkAsRead(messageIds);
  }

  Future<void> markAudioAsPlayed(String messageId) async {
    await _apiDataSource.markAudioAsPlayed(messageId);
  }

  /// Get statuses for multiple messages (polling fallback)
  /// Returns a map of messageId -> MessageStatus
  Future<Map<String, MessageStatus>> getMessageStatuses(List<String> messageIds) async {
    try {
      return await _apiDataSource.getMessageStatuses(messageIds);
    } catch (e) {
      print('[MessageRepository] Failed to get message statuses: $e');
      rethrow;
    }
  }

  /// Confirm delivery for multiple messages (after receiving push notification)
  Future<void> batchConfirmDelivery(List<String> messageIds) async {
    try {
      await _apiDataSource.batchConfirmDelivery(messageIds);
    } catch (e) {
      print('[MessageRepository] Failed to confirm delivery: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getStatusUpdates({
    required String chatId,
    DateTime? since,
  }) async {
    return await _apiDataSource.getStatusUpdates(chatId: chatId, since: since);
  }

  /// Получить обновления сообщений с определенного времени (incremental sync)
  Future<List<Message>> getMessageUpdates({
    required String chatId,
    required DateTime since,
    int take = 100,
  }) async {
    try {
      final messages = await _apiDataSource.getMessageUpdates(
        chatId: chatId,
        since: since,
        take: take,
      );

      // Cache the updates
      if (messages.isNotEmpty) {
        await _localDataSource.mergeMessagesToCache(chatId, messages);
      }

      return messages;
    } catch (e) {
      print('[MessageRepository] Failed to get message updates: $e');
      rethrow;
    }
  }

  /// Получить старые сообщения с курсорной пагинацией (для "загрузить ещё")
  Future<List<Message>> getOlderMessagesWithCursor({
    required String chatId,
    String? cursor,
    int take = 50,
  }) async {
    try {
      final messages = await _apiDataSource.getMessagesWithCursor(
        chatId: chatId,
        cursor: cursor,
        take: take,
      );

      // Merge with cache
      if (messages.isNotEmpty) {
        await _localDataSource.mergeMessagesToCache(chatId, messages);
      }

      return messages;
    } catch (e) {
      print('[MessageRepository] Failed to get messages with cursor: $e');
      rethrow;
    }
  }
  
  /// Edit a text message
  Future<Message> editMessage(String messageId, String newContent) async {
    return await _apiDataSource.editMessage(messageId, newContent);
  }
  
  /// Forward a message to another chat
  Future<Message> forwardMessage({
    required String originalMessageId,
    required String targetChatId,
  }) async {
    return await _apiDataSource.forwardMessage(
      originalMessageId: originalMessageId,
      targetChatId: targetChatId,
    );
  }
  
  /// Send a text message with reply
  Future<Message> sendMessageWithReply({
    required String chatId,
    required String content,
    required String replyToMessageId,
    String? clientMessageId,
  }) async {
    return await _apiDataSource.sendMessageWithReply(
      chatId: chatId,
      content: content,
      replyToMessageId: replyToMessageId,
      clientMessageId: clientMessageId,
    );
  }
}


