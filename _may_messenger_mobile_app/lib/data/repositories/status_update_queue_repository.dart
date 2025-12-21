import 'package:uuid/uuid.dart';
import '../models/status_update_model.dart';
import '../models/message_model.dart';
import '../datasources/local_datasource.dart';

/// Repository for managing pending status updates queue (persistent local storage)
class StatusUpdateQueueRepository {
  final LocalDataSource _localDataSource;
  final _uuid = const Uuid();
  
  // In-memory cache for quick access
  final Map<String, StatusUpdate> _pendingUpdates = {};

  StatusUpdateQueueRepository(this._localDataSource);

  /// Add a status update to the queue
  Future<void> enqueueStatusUpdate(String messageId, MessageStatus status) async {
    try {
      // Create unique ID for this status update
      final id = _uuid.v4();
      
      final statusUpdate = StatusUpdate(
        id: id,
        messageId: messageId,
        status: status,
        createdAt: DateTime.now(),
      );
      
      // Add to in-memory cache
      _pendingUpdates[id] = statusUpdate;
      
      // Persist to local storage
      await _localDataSource.saveStatusUpdate(statusUpdate);
      
      print('[StatusQueue] Enqueued status update: $messageId -> $status');
    } catch (e) {
      print('[StatusQueue] Error enqueuing status update: $e');
    }
  }

  /// Get all pending status updates
  Future<List<StatusUpdate>> getPendingUpdates() async {
    try {
      // Load from local storage if cache is empty
      if (_pendingUpdates.isEmpty) {
        final updates = await _localDataSource.getAllStatusUpdates();
        for (var update in updates) {
          _pendingUpdates[update.id] = update;
        }
      }
      
      return _pendingUpdates.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      print('[StatusQueue] Error getting pending updates: $e');
      return [];
    }
  }

  /// Mark a status update as sent (remove from queue)
  Future<void> markAsSent(String id) async {
    try {
      // Remove from cache
      _pendingUpdates.remove(id);
      
      // Remove from local storage
      await _localDataSource.deleteStatusUpdate(id);
      
      print('[StatusQueue] Marked status update as sent: $id');
    } catch (e) {
      print('[StatusQueue] Error marking as sent: $e');
    }
  }

  /// Update retry count for a status update
  Future<void> updateRetryCount(String id, int retryCount, {String? error}) async {
    try {
      final update = _pendingUpdates[id];
      if (update != null) {
        final updated = update.copyWith(
          retryCount: retryCount,
          lastRetryAt: DateTime.now(),
          error: error,
        );
        
        _pendingUpdates[id] = updated;
        await _localDataSource.saveStatusUpdate(updated);
        
        print('[StatusQueue] Updated retry count for $id: $retryCount');
      }
    } catch (e) {
      print('[StatusQueue] Error updating retry count: $e');
    }
  }

  /// Clean up old status updates (older than 7 days)
  Future<void> cleanup() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final toRemove = <String>[];
      
      for (var entry in _pendingUpdates.entries) {
        if (entry.value.createdAt.isBefore(cutoff)) {
          toRemove.add(entry.key);
        }
      }
      
      for (var id in toRemove) {
        await markAsSent(id);
      }
      
      if (toRemove.isNotEmpty) {
        print('[StatusQueue] Cleaned up ${toRemove.length} old status updates');
      }
    } catch (e) {
      print('[StatusQueue] Error during cleanup: $e');
    }
  }

  /// Get pending update count
  Future<int> getPendingCount() async {
    final updates = await getPendingUpdates();
    return updates.length;
  }

  /// Check if a specific status update is pending
  Future<bool> hasPendingUpdate(String messageId, MessageStatus status) async {
    final updates = await getPendingUpdates();
    return updates.any((u) => u.messageId == messageId && u.status == status);
  }
}

