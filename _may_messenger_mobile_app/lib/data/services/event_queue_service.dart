import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

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
    debugPrint('[EventQueueService] Initialized');
  }

  /// Enqueue an event for processing
  void enqueue(AppEvent event) {
    // Check for duplicate
    if (_processedEventIds.contains(event.eventId)) {
      _duplicatesSkipped++;
      debugPrint('[EventQueueService] Duplicate event skipped: ${event.type} (${event.eventId})');
      return;
    }

    _queue.add(event);
    debugPrint('[EventQueueService] Event enqueued: ${event.type} (queue size: ${_queue.length})');

    // Start processing if not already running
    _processQueue();
  }

  /// Register a handler for a specific event type
  void registerHandler(String eventType, Function(AppEvent) handler) {
    if (!_handlers.containsKey(eventType)) {
      _handlers[eventType] = [];
    }
    _handlers[eventType]!.add(handler);
    debugPrint('[EventQueueService] Handler registered for event type: $eventType');
  }

  /// Unregister all handlers for a specific event type
  void unregisterHandlers(String eventType) {
    _handlers.remove(eventType);
    debugPrint('[EventQueueService] Handlers unregistered for event type: $eventType');
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
          debugPrint('[EventQueueService] Event timeout: ${event.type} (${event.eventId})');
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
      debugPrint('[EventQueueService] Error processing queue: $e\n$stackTrace');
    } finally {
      _processing = false;
    }
  }

  /// Process a single event
  Future<void> _processEvent(AppEvent event) async {
    try {
      debugPrint('[EventQueueService] Processing event: ${event.type} (${event.eventId})');

      final handlers = _handlers[event.type];
      if (handlers == null || handlers.isEmpty) {
        debugPrint('[EventQueueService] No handlers registered for event type: ${event.type}');
        return;
      }

      // Call all registered handlers
      for (final handler in handlers) {
        try {
          await handler(event);
        } catch (e, stackTrace) {
          debugPrint('[EventQueueService] Error in handler for ${event.type}: $e\n$stackTrace');
        }
      }

      debugPrint('[EventQueueService] Event processed successfully: ${event.type}');
    } catch (e, stackTrace) {
      debugPrint('[EventQueueService] Error processing event: ${event.type}: $e\n$stackTrace');
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
    debugPrint('[EventQueueService] Queue cleared');
  }

  /// Dispose resources
  void dispose() {
    _queue.clear();
    _processedEventIds.clear();
    _handlers.clear();
    debugPrint('[EventQueueService] Disposed');
  }
}

