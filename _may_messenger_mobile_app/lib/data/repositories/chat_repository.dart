import '../datasources/api_datasource.dart';
import '../datasources/local_datasource.dart';
import '../models/chat_model.dart';

class ChatRepository {
  final ApiDataSource _apiDataSource;
  final LocalDataSource _localDataSource;

  ChatRepository(this._apiDataSource, this._localDataSource);

  Future<List<Chat>> getChats({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final cachedChats = await _localDataSource.getCachedChats();
        if (cachedChats != null && cachedChats.isNotEmpty) {
          return cachedChats;
        }
      } catch (e) {
        // Cache error - continue to API
      }
    }

    final chats = await _apiDataSource.getChats();
    await _localDataSource.cacheChats(chats);
    return chats;
  }

  Future<Chat> getChat(String chatId) async {
    return await _apiDataSource.getChat(chatId);
  }

  Future<Chat> createChat({
    required String title,
    required List<String> participantIds,
  }) async {
    return await _apiDataSource.createChat(
      title: title,
      participantIds: participantIds,
    );
  }

  Future<void> deleteChat(String chatId) async {
    await _apiDataSource.deleteChat(chatId);
    // Note: Local cache will be updated via SignalR notification
  }
}


