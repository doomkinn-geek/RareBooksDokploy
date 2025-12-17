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
    int take = 50,
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
}


