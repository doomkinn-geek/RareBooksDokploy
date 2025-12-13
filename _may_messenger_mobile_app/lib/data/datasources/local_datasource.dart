import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../../core/constants/storage_keys.dart';

class LocalDataSource {
  static const String _messagesBox = 'messages';
  static const String _chatsBox = 'chats';

  // Auth Storage
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.authToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.authToken);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.authToken);
  }

  // Messages Cache
  Future<void> cacheMessages(String chatId, List<Message> messages) async {
    final box = await Hive.openBox<Map>(_messagesBox);
    await box.put(chatId, {
      'messages': messages.map((m) => m.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Message>?> getCachedMessages(String chatId) async {
    final box = await Hive.openBox<Map>(_messagesBox);
    final data = box.get(chatId);
    if (data == null) return null;

    final messages = (data['messages'] as List)
        .map((json) => Message.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    return messages;
  }

  // Chats Cache
  Future<void> cacheChats(List<Chat> chats) async {
    final box = await Hive.openBox<Map>(_chatsBox);
    await box.put('chats', {
      'chats': chats.map((c) => c.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Chat>?> getCachedChats() async {
    try {
      final box = await Hive.openBox<Map>(_chatsBox);
      final data = box.get('chats');
      if (data == null) {
        return null;
      }

      final chats = (data['chats'] as List)
          .map((json) => Chat.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      
      return chats;
    } catch (e) {
      // Return null on error - will fetch from API
      return null;
    }
  }

  Future<void> clearCache() async {
    await Hive.deleteBoxFromDisk(_messagesBox);
    await Hive.deleteBoxFromDisk(_chatsBox);
  }
}


