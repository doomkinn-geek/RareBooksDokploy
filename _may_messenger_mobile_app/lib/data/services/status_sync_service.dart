import 'dart:async';
import '../models/status_update_model.dart';
import '../models/message_model.dart';
import '../repositories/status_update_queue_repository.dart';
import '../repositories/message_repository.dart';

/// Service for syncing pending status updates with exponential backoff retry
class StatusSyncService {
  final StatusUpdateQueueRepository _statusQueue;
  final MessageRepository _messageRepository;
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isDisposed = false;

  // Exponential backoff delays in seconds
  static const List<int> _backoffDelays = [2, 5, 10, 30, 60];
  static const int _maxRetries = 10;

  StatusSyncService(this._statusQueue, this._messageRepository);

  /// Start periodic syncing of pending status updates
  void startPeriodicSync({Duration interval = const Duration(seconds: 10)}) {
    if (_syncTimer != null) {
      print('[StatusSync] Already syncing, ignoring start request');
      return;
    }

    print('[StatusSync] Starting periodic status sync');
    
    // Immediate first sync
    _syncPendingStatuses();
    
    // Then periodic sync
    _syncTimer = Timer.periodic(interval, (_) {
      _syncPendingStatuses();
    });
  }

  /// Stop periodic syncing
  void stopSync() {
    if (_syncTimer != null) {
      print('[StatusSync] Stopping periodic status sync');
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  /// Manually trigger a sync (useful after reconnection)
  Future<void> syncNow() async {
    await _syncPendingStatuses();
  }

  /// Sync all pending status updates
  Future<void> _syncPendingStatuses() async {
    if (_isSyncing || _isDisposed) return;

    try {
      _isSyncing = true;
      
      final pendingUpdates = await _statusQueue.getPendingUpdates();
      
      if (pendingUpdates.isEmpty) {
        return;
      }

      print('[StatusSync] Syncing ${pendingUpdates.length} pending status updates');

      for (var update in pendingUpdates) {
        if (_isDisposed) break;
        
        await _syncSingleStatus(update);
      }

      // Cleanup old status updates
      await _statusQueue.cleanup();
      
    } catch (e) {
      print('[StatusSync] Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single status update with retry logic
  Future<void> _syncSingleStatus(StatusUpdate update) async {
    // Check if max retries exceeded
    if (update.retryCount >= _maxRetries) {
      print('[StatusSync] Max retries exceeded for status update ${update.id}, removing');
      await _statusQueue.markAsSent(update.id);
      return;
    }

    // Calculate backoff delay
    final delayIndex = update.retryCount < _backoffDelays.length 
        ? update.retryCount 
        : _backoffDelays.length - 1;
    final delaySeconds = _backoffDelays[delayIndex];

    // Check if enough time has passed since last retry
    if (update.lastRetryAt != null) {
      final timeSinceLastRetry = DateTime.now().difference(update.lastRetryAt!);
      if (timeSinceLastRetry.inSeconds < delaySeconds) {
        // Not time to retry yet
        return;
      }
    }

    try {
      // Send status update via API
      bool success = false;
      
      switch (update.status) {
        case MessageStatus.read:
          await _messageRepository.batchMarkAsRead([update.messageId]);
          success = true;
          break;
          
        case MessageStatus.played:
          await _messageRepository.markAudioAsPlayed(update.messageId);
          success = true;
          break;
          
        case MessageStatus.delivered:
          // Delivery is usually auto-tracked by backend, but we can add explicit API if needed
          success = true;
          break;
          
        default:
          // Other statuses don't need explicit API calls
          success = true;
          break;
      }

      if (success) {
        // Remove from queue
        await _statusQueue.markAsSent(update.id);
        print('[StatusSync] Successfully synced status update: ${update.messageId} -> ${update.status}');
      }
      
    } catch (e) {
      // Update retry count
      final newRetryCount = update.retryCount + 1;
      await _statusQueue.updateRetryCount(
        update.id, 
        newRetryCount, 
        error: e.toString(),
      );
      
      print('[StatusSync] Failed to sync status update ${update.id} (retry $newRetryCount/$_maxRetries): $e');
      
      if (newRetryCount >= _maxRetries) {
        print('[StatusSync] Max retries reached, will remove on next sync');
      }
    }
  }

  /// Get count of pending status updates
  Future<int> getPendingCount() async {
    return await _statusQueue.getPendingCount();
  }

  /// Check if syncing is active
  bool get isSyncing => _isSyncing;

  /// Check if periodic sync is running
  bool get isPeriodicSyncActive => _syncTimer != null && _syncTimer!.isActive;

  /// Force immediate sync of all pending statuses (useful after reconnect)
  Future<void> forceSync() async {
    print('[StatusSync] Force sync requested');
    await _syncPendingStatuses();
  }

  /// Get statistics about pending status updates
  Future<Map<String, int>> getStatistics() async {
    try {
      final pendingUpdates = await _statusQueue.getPendingUpdates();
      
      final Map<String, int> stats = {
        'total': pendingUpdates.length,
        'read': 0,
        'played': 0,
        'delivered': 0,
        'failed': 0,
      };
      
      for (var update in pendingUpdates) {
        switch (update.status) {
          case MessageStatus.read:
            stats['read'] = (stats['read'] ?? 0) + 1;
            break;
          case MessageStatus.played:
            stats['played'] = (stats['played'] ?? 0) + 1;
            break;
          case MessageStatus.delivered:
            stats['delivered'] = (stats['delivered'] ?? 0) + 1;
            break;
          default:
            break;
        }
        
        if (update.retryCount >= _maxRetries) {
          stats['failed'] = (stats['failed'] ?? 0) + 1;
        }
      }
      
      return stats;
    } catch (e) {
      print('[StatusSync] Failed to get statistics: $e');
      return {};
    }
  }

  void dispose() {
    _isDisposed = true;
    stopSync();
  }
}

