import 'dart:collection';
import 'package:logging/logging.dart';
import '../../domain/models/message.dart';

/// LRU (Least Recently Used) кэш для сообщений
/// Хранит последние N сообщений в памяти для быстрого доступа
class MessageCacheRepository {
  static const int _maxCacheSize = 500; // Максимум сообщений в кэше
  static const int _chatMessagesLimit = 100; // Сообщений на чат
  
  final _logger = Logger('MessageCacheRepository');
  
  // LRU cache: ключ - ID сообщения, значение - сообщение
  final _cache = LinkedHashMap<String, Message>();
  
  // Индекс по chatId для быстрого поиска
  final _chatIndex = <String, LinkedHashSet<String>>{};
  
  // Порядок доступа для LRU (последние используемые)
  final _accessOrder = <String>[];

  /// Добавить сообщение в кэш
  void put(Message message) {
    try {
      // Если сообщение уже есть, обновляем его
      if (_cache.containsKey(message.id)) {
        _updateAccessOrder(message.id);
        _cache[message.id] = message;
        return;
      }

      // Проверяем лимит кэша
      if (_cache.length >= _maxCacheSize) {
        _evictOldest();
      }

      // Добавляем в кэш
      _cache[message.id] = message;
      _accessOrder.add(message.id);

      // Обновляем индекс по chatId
      _chatIndex.putIfAbsent(message.chatId, () => LinkedHashSet<String>());
      _chatIndex[message.chatId]!.add(message.id);

      // Проверяем лимит сообщений для чата
      _enforcePerChatLimit(message.chatId);
    } catch (e, stackTrace) {
      _logger.severe('Error adding message to cache', e, stackTrace);
    }
  }

  /// Добавить несколько сообщений
  void putAll(List<Message> messages) {
    for (final message in messages) {
      put(message);
    }
  }

  /// Получить сообщение по ID
  Message? get(String messageId) {
    if (!_cache.containsKey(messageId)) {
      return null;
    }
    
    _updateAccessOrder(messageId);
    return _cache[messageId];
  }

  /// Получить все сообщения для чата (отсортированы по времени)
  List<Message> getChatMessages(String chatId) {
    final messageIds = _chatIndex[chatId];
    if (messageIds == null || messageIds.isEmpty) {
      return [];
    }

    final messages = <Message>[];
    for (final messageId in messageIds) {
      final message = _cache[messageId];
      if (message != null) {
        messages.add(message);
        _updateAccessOrder(messageId);
      }
    }

    // Сортируем по времени (новые в конце)
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  /// Получить последние N сообщений для чата
  List<Message> getLastMessages(String chatId, int limit) {
    final messages = getChatMessages(chatId);
    if (messages.length <= limit) {
      return messages;
    }
    return messages.sublist(messages.length - limit);
  }

  /// Удалить сообщение из кэша
  void remove(String messageId) {
    final message = _cache.remove(messageId);
    if (message != null) {
      _accessOrder.remove(messageId);
      _chatIndex[message.chatId]?.remove(messageId);
    }
  }

  /// Удалить все сообщения чата из кэша
  void removeChatMessages(String chatId) {
    final messageIds = _chatIndex[chatId];
    if (messageIds != null) {
      for (final messageId in messageIds.toList()) {
        _cache.remove(messageId);
        _accessOrder.remove(messageId);
      }
      _chatIndex.remove(chatId);
    }
  }

  /// Обновить сообщение в кэше
  void update(Message message) {
    if (_cache.containsKey(message.id)) {
      _cache[message.id] = message;
      _updateAccessOrder(message.id);
    }
  }

  /// Проверить, есть ли сообщение в кэше
  bool contains(String messageId) {
    return _cache.containsKey(messageId);
  }

  /// Очистить весь кэш
  void clear() {
    _cache.clear();
    _chatIndex.clear();
    _accessOrder.clear();
    _logger.info('Message cache cleared');
  }

  /// Получить размер кэша
  int get size => _cache.length;

  /// Получить количество сообщений в чате
  int getChatMessagesCount(String chatId) {
    return _chatIndex[chatId]?.length ?? 0;
  }

  /// Удалить самое старое (давно не использовавшееся) сообщение
  void _evictOldest() {
    if (_accessOrder.isEmpty) return;

    final oldestId = _accessOrder.removeAt(0);
    final message = _cache.remove(oldestId);
    
    if (message != null) {
      _chatIndex[message.chatId]?.remove(oldestId);
      _logger.fine('Evicted message $oldestId from cache (LRU)');
    }
  }

  /// Обновить порядок доступа (переместить в конец)
  void _updateAccessOrder(String messageId) {
    _accessOrder.remove(messageId);
    _accessOrder.add(messageId);
  }

  /// Ограничить количество сообщений для конкретного чата
  void _enforcePerChatLimit(String chatId) {
    final messageIds = _chatIndex[chatId];
    if (messageIds == null) return;

    while (messageIds.length > _chatMessagesLimit) {
      // Удаляем самое старое сообщение из чата
      final oldestId = messageIds.first;
      messageIds.remove(oldestId);
      _cache.remove(oldestId);
      _accessOrder.remove(oldestId);
      
      _logger.fine('Evicted message $oldestId from chat $chatId (per-chat limit)');
    }
  }

  /// Получить статистику кэша
  Map<String, dynamic> getStats() {
    return {
      'total_messages': _cache.length,
      'total_chats': _chatIndex.length,
      'max_cache_size': _maxCacheSize,
      'chat_messages_limit': _chatMessagesLimit,
      'cache_usage_percent': (_cache.length / _maxCacheSize * 100).toStringAsFixed(1),
      'chats': _chatIndex.map((chatId, messageIds) => MapEntry(
        chatId,
        {
          'message_count': messageIds.length,
          'messages': messageIds.take(5).toList(), // First 5 IDs
        },
      )),
    };
  }
}

