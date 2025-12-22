import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Base class for all events processed by the queue
abstract class AppEvent {
  final DateTime timestamp;
  final String eventId;

  AppEvent({DateTime? timestamp, String? eventId})
      : timestamp = timestamp ?? DateTime.now(),
        eventId = eventId ?? DateTime.now().millisecondsSinceEpoch.toString();

  String get type;
}

/// Message received via SignalR
class MessageReceivedEvent extends AppEvent {
  final Map<String, dynamic> messageData;
  final String chatId;

  MessageReceivedEvent({
    required this.messageData,
    required this.chatId,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'MessageReceived';
}

/// Message sent successfully via REST API
class MessageSentEvent extends AppEvent {
  final String messageId;
  final String chatId;
  final String? clientMessageId;

  MessageSentEvent({
    required this.messageId,
    required this.chatId,
    this.clientMessageId,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'MessageSent';
}

/// Message status update (delivered, read, played)
class StatusUpdateEvent extends AppEvent {
  final String messageId;
  final int newStatus;
  final String source; // 'SignalR', 'REST', 'Local'

  StatusUpdateEvent({
    required this.messageId,
    required this.newStatus,
    required this.source,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'StatusUpdate';
}

/// Sync completed event
class SyncCompleteEvent extends AppEvent {
  final String chatId;
  final int messageCount;

  SyncCompleteEvent({
    required this.chatId,
    required this.messageCount,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'SyncComplete';
}

/// User status changed (online/offline)
class UserStatusChangedEvent extends AppEvent {
  final String userId;
  final bool isOnline;
  final DateTime lastSeenAt;

  UserStatusChangedEvent({
    required this.userId,
    required this.isOnline,
    required this.lastSeenAt,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'UserStatusChanged';
}

/// Typing indicator event
class TypingIndicatorEvent extends AppEvent {
  final String chatId;
  final String userId;
  final bool isTyping;

  TypingIndicatorEvent({
    required this.chatId,
    required this.userId,
    required this.isTyping,
    super.timestamp,
    super.eventId,
  });

  @override
  String get type => 'TypingIndicator';
}

/// Centralized event queue service for processing all app events sequentially
/// Ensures deduplication and ordered processing
class EventQueueService {
  final Logger _logger = Logger();
  final Queue<AppEvent> _queue = Queue();
  final Set<String> _processedEventIds = {};
  bool _processing = false;

  // Event handlers
  final Map<String, List<Function(AppEvent)>> _handlers = {};

  // Statistics
  int _totalEventsProcessed = 0;
  int _duplicatesSkipped = 0;
  DateTime? _lastProcessedAt;

  // Configuration
  static const int maxProcessedEventIdsSize = 1000;
  static const Duration eventTimeout = Duration(seconds: 30);

  EventQueueService() {
    _logger.d('[EventQueueService] Initialized');
  }

  /// Enqueue an event for processing
  void enqueue(AppEvent event) {
    // Check for duplicate
    if (_processedEventIds.contains(event.eventId)) {
      _duplicatesSkipped++;
      _logger.w('[EventQueueService] Duplicate event skipped: ${event.type} (${event.eventId})');
      return;
    }

    _queue.add(event);
    _logger.d('[EventQueueService] Event enqueued: ${event.type} (queue size: ${_queue.length})');

    // Start processing if not already running
    _processQueue();
  }

  /// Register a handler for a specific event type
  void registerHandler(String eventType, Function(AppEvent) handler) {
    if (!_handlers.containsKey(eventType)) {
      _handlers[eventType] = [];
    }
    _handlers[eventType]!.add(handler);
    _logger.d('[EventQueueService] Handler registered for event type: $eventType');
  }

  /// Unregister all handlers for a specific event type
  void unregisterHandlers(String eventType) {
    _handlers.remove(eventType);
    _logger.d('[EventQueueService] Handlers unregistered for event type: $eventType');
  }

  /// Process the queue sequentially
  Future<void> _processQueue() async {
    if (_processing) {
      return; // Already processing
    }

    _processing = true;

    try {
      while (_queue.isNotEmpty) {
        final event = _queue.removeFirst();

        // Check if event is too old (timeout)
        if (DateTime.now().difference(event.timestamp) > eventTimeout) {
          _logger.w('[EventQueueService] Event timeout: ${event.type} (${event.eventId})');
          continue;
        }

        // Process event
        await _processEvent(event);

        // Mark as processed
        _processedEventIds.add(event.eventId);
        _totalEventsProcessed++;
        _lastProcessedAt = DateTime.now();

        // Cleanup old processed event IDs to prevent memory leak
        if (_processedEventIds.length > maxProcessedEventIdsSize) {
          final toRemove = _processedEventIds.length - maxProcessedEventIdsSize;
          _processedEventIds.removeAll(_processedEventIds.take(toRemove));
        }
      }
    } catch (e, stackTrace) {
      _logger.e('[EventQueueService] Error processing queue', error: e, stackTrace: stackTrace);
    } finally {
      _processing = false;
    }
  }

  /// Process a single event
  Future<void> _processEvent(AppEvent event) async {
    try {
      _logger.d('[EventQueueService] Processing event: ${event.type} (${event.eventId})');

      final handlers = _handlers[event.type];
      if (handlers == null || handlers.isEmpty) {
        _logger.w('[EventQueueService] No handlers registered for event type: ${event.type}');
        return;
      }

      // Call all registered handlers
      for (final handler in handlers) {
        try {
          await handler(event);
        } catch (e, stackTrace) {
          _logger.e('[EventQueueService] Error in handler for ${event.type}', error: e, stackTrace: stackTrace);
        }
      }

      _logger.d('[EventQueueService] Event processed successfully: ${event.type}');
    } catch (e, stackTrace) {
      _logger.e('[EventQueueService] Error processing event: ${event.type}', error: e, stackTrace: stackTrace);
    }
  }

  /// Get queue statistics
  Map<String, dynamic> getStats() {
    return {
      'queueSize': _queue.length,
      'totalEventsProcessed': _totalEventsProcessed,
      'duplicatesSkipped': _duplicatesSkipped,
      'lastProcessedAt': _lastProcessedAt?.toIso8601String(),
      'isProcessing': _processing,
      'processedEventIdsSize': _processedEventIds.length,
    };
  }

  /// Clear the queue (use with caution)
  void clear() {
    _queue.clear();
    _logger.w('[EventQueueService] Queue cleared');
  }

  /// Dispose resources
  void dispose() {
    _queue.clear();
    _processedEventIds.clear();
    _handlers.clear();
    _logger.d('[EventQueueService] Disposed');
  }
}

