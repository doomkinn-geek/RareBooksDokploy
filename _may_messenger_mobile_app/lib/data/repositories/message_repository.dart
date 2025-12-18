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
    // #region agent log H10
    print('[H10-Repo] getMessages: chatId=$chatId, skip=$skip, take=$take, forceRefresh=$forceRefresh');
    // #endregion
    
    if (!forceRefresh && skip == 0) {
      final cachedMessages = await _localDataSource.getCachedMessages(chatId);
      
      // #region agent log H10
      print('[H10-Repo] Hive cache result: ${cachedMessages?.length ?? 0} messages');
      // #endregion
      
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        return cachedMessages;
      }
    }

    // #region agent log H10
    print('[H10-Repo] Calling API getMessages...');
    // #endregion
    
    final messages = await _apiDataSource.getMessages(
      chatId: chatId,
      skip: skip,
      take: take,
    );

    // #region agent log H10
    print('[H10-Repo] API returned ${messages.length} messages');
    // #endregion

    if (skip == 0) {
      await _localDataSource.cacheMessages(chatId, messages);
      
      // #region agent log H10
      print('[H10-Repo] Cached ${messages.length} messages in Hive');
      // #endregion
    }

    return messages;
  }

  Future<Message> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
  }) async {
    return await _apiDataSource.sendMessage(
      chatId: chatId,
      type: type,
      content: content,
    );
  }

  Future<Message> sendAudioMessage({
    required String chatId,
    required String audioPath,
  }) async {
    return await _apiDataSource.sendAudioMessage(
      chatId: chatId,
      audioPath: audioPath,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _apiDataSource.deleteMessage(messageId);
    // Note: Local cache will be updated via SignalR notification
  }

  Future<void> batchMarkAsRead(List<String> messageIds) async {
    await _apiDataSource.batchMarkAsRead(messageIds);
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
}


