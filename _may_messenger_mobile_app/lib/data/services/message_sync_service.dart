import 'dart:async';
import '../repositories/message_repository.dart';
import '../models/message_model.dart';

/// Service for syncing message status when SignalR is unavailable
class MessageSyncService {
  final MessageRepository _messageRepository;
  Timer? _pollTimer;
  DateTime? _lastSync;
  bool _isPolling = false;

  MessageSyncService(this._messageRepository);

  /// Start polling for status updates
  void startPolling({
    required String chatId,
    required Function(String messageId, MessageStatus status) onStatusUpdate,
    Duration interval = const Duration(seconds: 5),
  }) {
    if (_isPolling) {
      print('[SYNC] Already polling, ignoring start request');
      return;
    }

    print('[SYNC] Starting status polling for chat: $chatId');
    _isPolling = true;
    _lastSync = DateTime.now().subtract(const Duration(minutes: 5));

    _pollTimer = Timer.periodic(interval, (timer) async {
      try {
        await _pollStatusUpdates(chatId, onStatusUpdate);
      } catch (e) {
        print('[SYNC] Polling error: $e');
      }
    });
  }

  /// Poll for status updates
  Future<void> _pollStatusUpdates(
    String chatId,
    Function(String messageId, MessageStatus status) onStatusUpdate,
  ) async {
    try {
      final updates = await _messageRepository.getStatusUpdates(
        chatId: chatId,
        since: _lastSync,
      );

      if (updates.isNotEmpty) {
        print('[SYNC] Received ${updates.length} status updates via polling');

        for (final update in updates) {
          try {
            final messageId = update['messageId'] as String;
            final statusInt = update['status'] as int;
            final status = MessageStatus.values[statusInt];

            onStatusUpdate(messageId, status);
          } catch (e) {
            print('[SYNC] Failed to process status update: $e');
          }
        }
      }

      _lastSync = DateTime.now();
    } catch (e) {
      print('[SYNC] Failed to poll status updates: $e');
    }
  }

  /// Stop polling
  void stopPolling() {
    if (_pollTimer != null) {
      print('[SYNC] Stopping status polling');
      _pollTimer?.cancel();
      _pollTimer = null;
      _isPolling = false;
    }
  }

  /// Check if currently polling
  bool get isPolling => _isPolling;

  /// Manually trigger a sync (useful after reconnection)
  Future<void> syncNow({
    required String chatId,
    required Function(String messageId, MessageStatus status) onStatusUpdate,
  }) async {
    print('[SYNC] Manual sync triggered for chat: $chatId');
    await _pollStatusUpdates(chatId, onStatusUpdate);
  }

  void dispose() {
    stopPolling();
  }
}

