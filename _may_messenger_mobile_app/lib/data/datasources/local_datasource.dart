import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/status_update_model.dart';
import '../models/contact_cache_model.dart';
import '../repositories/outbox_repository.dart';
import '../../core/constants/storage_keys.dart';

class LocalDataSource {
  static const String _messagesBox = 'messages';
  static const String _chatsBox = 'chats';
  static const String _outboxBox = 'outbox';
  static const String _statusUpdatesBox = 'status_updates';
  static const String _contactsCacheBox = 'contacts_cache';

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
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      
      await box.put(chatId, {
        'messages': messages.map((m) => m.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Force flush to disk to ensure persistence
      await box.flush();
    } catch (e) {
      print('[Cache] ERROR caching messages: $e');
      rethrow;
    }
  }

  Future<List<Message>?> getCachedMessages(String chatId) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      
      final data = box.get(chatId);
      if (data == null) {
        return null;
      }

      final messages = (data['messages'] as List)
          .map((json) => Message.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      
      return messages;
    } catch (e) {
      print('[Cache] ERROR loading from cache: $e');
      return null;
    }
  }

  // Add single message to cache
  Future<void> addMessageToCache(String chatId, Message message) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      
      List<Message> messages = [];
      if (data != null) {
        messages = (data['messages'] as List)
            .map((json) => Message.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      
      // Check if message already exists
      final exists = messages.any((m) => m.id == message.id);
      if (!exists) {
        messages.add(message);
        // Sort by date (ascending - oldest first, newest last)
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        await box.put(chatId, {
          'messages': messages.map((m) => m.toJson()).toList(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Failed to add message to cache: $e');
    }
  }

  // Merge multiple messages to cache (for incremental sync)
  Future<void> mergeMessagesToCache(String chatId, List<Message> newMessages) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      
      // Get existing messages
      List<Message> existingMessages = [];
      if (data != null) {
        existingMessages = (data['messages'] as List)
            .map((json) => Message.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      
      // Create a map of existing messages by ID for quick lookup
      final existingMap = <String, Message>{
        for (var msg in existingMessages) msg.id: msg
      };
      
      // Merge: add new messages or update existing ones
      for (var newMessage in newMessages) {
        if (existingMap.containsKey(newMessage.id)) {
          // Update existing message (e.g., status changed)
          existingMap[newMessage.id] = newMessage;
        } else {
          // Add new message
          existingMap[newMessage.id] = newMessage;
        }
      }
      
      // Convert back to list and sort
      final mergedMessages = existingMap.values.toList();
      mergedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      await box.put(chatId, {
        'messages': mergedMessages.map((m) => m.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      print('[LocalDataSource] Merged ${newMessages.length} messages to cache for chat $chatId');
    } catch (e) {
      print('[LocalDataSource] Failed to merge messages to cache: $e');
    }
  }

  // Get last sync timestamp for a chat
  Future<DateTime?> getLastSyncTimestamp(String chatId) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      if (data == null) return null;
      
      final timestampStr = data['timestamp'] as String?;
      if (timestampStr != null) {
        return DateTime.parse(timestampStr);
      }
      return null;
    } catch (e) {
      print('[LocalDataSource] Failed to get last sync timestamp: $e');
      return null;
    }
  }

  /// Save last sync timestamp for a chat
  Future<void> saveLastSyncTimestamp(String chatId, DateTime timestamp) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId) ?? <String, dynamic>{};
      data['timestamp'] = timestamp.toIso8601String();
      await box.put(chatId, data);
      print('[LocalDataSource] Saved last sync timestamp for chat $chatId: $timestamp');
    } catch (e) {
      print('[LocalDataSource] Failed to save last sync timestamp: $e');
    }
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

  // Update local audio path for a message
  Future<void> updateMessageLocalAudioPath(String chatId, String messageId, String localPath) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      if (data == null) return;

      final messages = (data['messages'] as List)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      
      // Find and update the message
      for (var message in messages) {
        if (message['id'] == messageId) {
          message['localAudioPath'] = localPath;
          break;
        }
      }
      
      await box.put(chatId, {
        'messages': messages,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail - not critical
    }
  }

  // Update message status in cache
  Future<void> updateMessageStatus(String chatId, String messageId, MessageStatus status) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      if (data == null) return;

      final messages = (data['messages'] as List)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      
      // Find and update the message status
      bool updated = false;
      for (var message in messages) {
        if (message['id'] == messageId) {
          message['status'] = status.index;
          updated = true;
          break;
        }
      }
      
      if (updated) {
        await box.put(chatId, {
          'messages': messages,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('[LocalDataSource] Failed to update message status: $e');
    }
  }

  // Get cached message statuses for a chat (used to preserve played status)
  Future<Map<String, MessageStatus>> getCachedMessageStatuses(String chatId) async {
    try {
      final box = await Hive.openBox<Map>(_messagesBox);
      final data = box.get(chatId);
      if (data == null) return {};

      final messages = (data['messages'] as List)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      
      final Map<String, MessageStatus> statuses = {};
      for (var message in messages) {
        final id = message['id'] as String?;
        final statusIndex = message['status'] as int?;
        if (id != null && statusIndex != null && statusIndex < MessageStatus.values.length) {
          statuses[id] = MessageStatus.values[statusIndex];
        }
      }
      
      print('[LocalDataSource] Retrieved ${statuses.length} cached message statuses for chat $chatId');
      return statuses;
    } catch (e) {
      print('[LocalDataSource] Failed to get cached message statuses: $e');
      return {};
    }
  }

  // Update chat last message in cache
  Future<void> updateChatLastMessage(String chatId, Message message) async {
    try {
      final box = await Hive.openBox<Map>(_chatsBox);
      final data = box.get('chats');
      if (data == null) return;

      final chats = (data['chats'] as List)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      
      // Find and update the chat
      bool updated = false;
      for (var chat in chats) {
        if (chat['id'] == chatId) {
          chat['lastMessage'] = message.toJson();
          updated = true;
          break;
        }
      }
      
      if (updated) {
        await box.put('chats', {
          'chats': chats,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('[LocalDataSource] Failed to update chat last message: $e');
    }
  }

  Future<void> clearCache() async {
    await Hive.deleteBoxFromDisk(_messagesBox);
    await Hive.deleteBoxFromDisk(_chatsBox);
  }

  // ==================== OUTBOX / PENDING MESSAGES ====================

  /// Add a pending message to the outbox
  Future<void> addPendingMessage(PendingMessage message) async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      await box.put(message.localId, message.toJson());
    } catch (e) {
      print('[LocalDataSource] Failed to add pending message: $e');
      rethrow;
    }
  }

  /// Get all pending messages for a specific chat
  Future<List<PendingMessage>> getPendingMessagesForChat(String chatId) async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      final allMessages = <PendingMessage>[];
      
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final message = PendingMessage.fromJson(Map<String, dynamic>.from(data));
          if (message.chatId == chatId) {
            allMessages.add(message);
          }
        }
      }
      
      // Sort by creation time (oldest first)
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return allMessages;
    } catch (e) {
      print('[LocalDataSource] Failed to get pending messages for chat: $e');
      return [];
    }
  }

  /// Get all pending messages across all chats
  Future<List<PendingMessage>> getAllPendingMessages() async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      final allMessages = <PendingMessage>[];
      
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          final message = PendingMessage.fromJson(Map<String, dynamic>.from(data));
          allMessages.add(message);
        }
      }
      
      // Sort by creation time (oldest first)
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return allMessages;
    } catch (e) {
      print('[LocalDataSource] Failed to get all pending messages: $e');
      return [];
    }
  }

  /// Get a specific pending message by local ID
  Future<PendingMessage?> getPendingMessageById(String localId) async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      final data = box.get(localId);
      
      if (data != null) {
        return PendingMessage.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print('[LocalDataSource] Failed to get pending message by ID: $e');
      return null;
    }
  }

  /// Update a pending message
  Future<void> updatePendingMessage(PendingMessage message) async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      await box.put(message.localId, message.toJson());
    } catch (e) {
      print('[LocalDataSource] Failed to update pending message: $e');
      rethrow;
    }
  }

  /// Remove a pending message from outbox
  Future<void> removePendingMessage(String localId) async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      await box.delete(localId);
    } catch (e) {
      print('[LocalDataSource] Failed to remove pending message: $e');
      rethrow;
    }
  }

  /// Clear all pending messages (use with caution)
  Future<void> clearAllPendingMessages() async {
    try {
      final box = await Hive.openBox<Map>(_outboxBox);
      await box.clear();
      print('[LocalDataSource] Cleared all pending messages');
    } catch (e) {
      print('[LocalDataSource] Failed to clear pending messages: $e');
    }
  }

  // Status Updates Queue Management
  
  /// Save a status update to the queue
  Future<void> saveStatusUpdate(StatusUpdate statusUpdate) async {
    try {
      final box = await Hive.openBox<Map>(_statusUpdatesBox);
      await box.put(statusUpdate.id, statusUpdate.toJson());
      await box.flush();
    } catch (e) {
      print('[LocalDataSource] Failed to save status update: $e');
      rethrow;
    }
  }

  /// Get all pending status updates
  Future<List<StatusUpdate>> getAllStatusUpdates() async {
    try {
      final box = await Hive.openBox<Map>(_statusUpdatesBox);
      final updates = <StatusUpdate>[];
      
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          updates.add(StatusUpdate.fromJson(Map<String, dynamic>.from(data)));
        }
      }
      
      return updates;
    } catch (e) {
      print('[LocalDataSource] Failed to get all status updates: $e');
      return [];
    }
  }

  /// Delete a status update from the queue
  Future<void> deleteStatusUpdate(String id) async {
    try {
      final box = await Hive.openBox<Map>(_statusUpdatesBox);
      await box.delete(id);
    } catch (e) {
      print('[LocalDataSource] Failed to delete status update: $e');
      rethrow;
    }
  }

  /// Clear all status updates (use with caution)
  Future<void> clearAllStatusUpdates() async {
    try {
      final box = await Hive.openBox<Map>(_statusUpdatesBox);
      await box.clear();
      print('[LocalDataSource] Cleared all status updates');
    } catch (e) {
      print('[LocalDataSource] Failed to clear status updates: $e');
    }
  }

  // Contacts Cache
  /// Save contacts cache
  Future<void> saveContactsCache(List<ContactCache> contacts) async {
    try {
      final box = await Hive.openBox<Map>(_contactsCacheBox);
      final data = {
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await box.put('cache', data);
      await box.flush();
      print('[ContactsCache] Saved ${contacts.length} contacts to cache');
    } catch (e) {
      print('[ContactsCache] Failed to save contacts cache: $e');
      rethrow;
    }
  }

  /// Get cached contacts
  Future<List<ContactCache>?> getContactsCache() async {
    try {
      final box = await Hive.openBox<Map>(_contactsCacheBox);
      final data = box.get('cache');
      if (data == null) {
        return null;
      }

      final contacts = (data['contacts'] as List)
          .map((json) => ContactCache.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      
      return contacts;
    } catch (e) {
      print('[ContactsCache] Failed to get contacts cache: $e');
      return null;
    }
  }

  /// Search cached contacts by name
  Future<List<ContactCache>> searchContactsCache(String query) async {
    try {
      final contacts = await getContactsCache();
      if (contacts == null) {
        return [];
      }

      return contacts
          .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('[ContactsCache] Failed to search contacts cache: $e');
      return [];
    }
  }

  /// Clear contacts cache
  Future<void> clearContactsCache() async {
    try {
      final box = await Hive.openBox<Map>(_contactsCacheBox);
      await box.clear();
      print('[ContactsCache] Cleared contacts cache');
    } catch (e) {
      print('[ContactsCache] Failed to clear contacts cache: $e');
      rethrow;
    }
  }
}


