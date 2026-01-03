import 'dart:async';
import '../repositories/outbox_repository.dart';
import '../repositories/message_repository.dart';
import '../models/message_model.dart';

/// Service responsible for synchronizing pending messages from the outbox to the server.
/// Automatically triggered on SignalR reconnection and runs periodically.
class OutboxSyncService {
  final OutboxRepository _outboxRepository;
  final MessageRepository _messageRepository;
  
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  bool _isConnected = false;
  
  // Callbacks for UI updates
  Function(String localId, String serverId, MessageStatus status)? onMessageSynced;
  Function(String localId, String error)? onMessageFailed;
  
  // Configuration
  static const Duration _periodicSyncInterval = Duration(seconds: 15);
  static const int _maxConcurrentSyncs = 3;
  static const int _maxRetries = 5; // Max retry attempts before giving up
  static const Duration _baseRetryDelay = Duration(seconds: 2); // Base delay for exponential backoff
  
  OutboxSyncService(this._outboxRepository, this._messageRepository);
  
  /// Update connection status
  void setConnected(bool connected) {
    final wasConnected = _isConnected;
    _isConnected = connected;
    
    // If we just connected, trigger immediate sync
    if (!wasConnected && connected) {
      print('[OUTBOX_SYNC] Connection restored, triggering immediate sync');
      syncPendingMessages();
    }
  }
  
  /// Start periodic sync timer
  void startPeriodicSync() {
    stopPeriodicSync();
    
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (_isConnected) {
        syncPendingMessages();
      }
    });
    
    print('[OUTBOX_SYNC] Periodic sync started (interval: $_periodicSyncInterval)');
  }
  
  /// Stop periodic sync timer
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
  
  /// Force sync all pending messages immediately
  /// Called when SignalR reconnects or when entering a chat
  Future<void> syncPendingMessages() async {
    if (_isSyncing) {
      print('[OUTBOX_SYNC] Already syncing, skipping...');
      return;
    }
    
    if (!_isConnected) {
      print('[OUTBOX_SYNC] Not connected, skipping sync');
      return;
    }
    
    _isSyncing = true;
    
    try {
      await _outboxRepository.initialize();
      
      // Get all pending messages that need to be synced
      final allPending = await _outboxRepository.getAllPendingMessages();
      
      // Filter to only localOnly and failed (for retry)
      // Also check retry count and apply exponential backoff
      final now = DateTime.now();
      final toSync = allPending.where((msg) {
        if (msg.syncState == SyncState.localOnly) {
          return true;
        }
        
        if (msg.syncState == SyncState.failed) {
          // Check if max retries exceeded
          if (msg.retryCount >= _maxRetries) {
            return false; // Skip - too many retries
          }
          
          // Apply exponential backoff: 2^retryCount * baseDelay
          // E.g., 2s, 4s, 8s, 16s, 32s
          final backoffSeconds = _baseRetryDelay.inSeconds * (1 << msg.retryCount);
          final retryAfter = msg.createdAt.add(Duration(seconds: backoffSeconds));
          
          return now.isAfter(retryAfter); // Only retry if backoff period elapsed
        }
        
        return false;
      }).toList();
      
      if (toSync.isEmpty) {
        print('[OUTBOX_SYNC] No pending messages to sync');
        _isSyncing = false;
        return;
      }
      
      print('[OUTBOX_SYNC] Found ${toSync.length} messages to sync');
      
      // Sort by creation date (oldest first)
      toSync.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Process in batches to avoid overwhelming the server
      int synced = 0;
      int failed = 0;
      
      for (int i = 0; i < toSync.length; i += _maxConcurrentSyncs) {
        if (!_isConnected) {
          print('[OUTBOX_SYNC] Lost connection during sync, stopping');
          break;
        }
        
        final batch = toSync.skip(i).take(_maxConcurrentSyncs).toList();
        
        // Process batch concurrently
        final results = await Future.wait(
          batch.map((msg) => _syncSingleMessage(msg)),
          eagerError: false,
        );
        
        for (final result in results) {
          if (result) {
            synced++;
          } else {
            failed++;
          }
        }
        
        // Small delay between batches to avoid rate limiting
        if (i + _maxConcurrentSyncs < toSync.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      print('[OUTBOX_SYNC] Sync completed: $synced succeeded, $failed failed');
      
    } catch (e) {
      print('[OUTBOX_SYNC] Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Sync messages for a specific chat
  Future<void> syncMessagesForChat(String chatId) async {
    if (!_isConnected) {
      print('[OUTBOX_SYNC] Not connected, skipping chat sync for $chatId');
      return;
    }
    
    try {
      await _outboxRepository.initialize();
      
      final pending = await _outboxRepository.getPendingMessagesForChat(chatId);
      
      // Filter to only localOnly and failed (for retry)
      final now = DateTime.now();
      final toSync = pending.where((msg) {
        if (msg.syncState == SyncState.localOnly) {
          return true;
        }
        
        if (msg.syncState == SyncState.failed) {
          // Check if max retries exceeded
          if (msg.retryCount >= _maxRetries) {
            return false;
          }
          
          // Apply exponential backoff
          final backoffSeconds = _baseRetryDelay.inSeconds * (1 << msg.retryCount);
          final retryAfter = msg.createdAt.add(Duration(seconds: backoffSeconds));
          
          return now.isAfter(retryAfter);
        }
        
        return false;
      }).toList();
      
      if (toSync.isEmpty) {
        print('[OUTBOX_SYNC] No pending messages to sync for chat $chatId');
        return;
      }
      
      print('[OUTBOX_SYNC] Syncing ${toSync.length} messages for chat $chatId');
      
      // Sort by creation date (oldest first)
      toSync.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      for (final msg in toSync) {
        if (!_isConnected) break;
        await _syncSingleMessage(msg);
        // Small delay between messages
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
    } catch (e) {
      print('[OUTBOX_SYNC] Error syncing chat $chatId: $e');
    }
  }
  
  /// Sync a single message and handle result
  Future<bool> _syncSingleMessage(PendingMessage msg) async {
    try {
      print('[OUTBOX_SYNC] Syncing message ${msg.localId} (type: ${msg.type}, chat: ${msg.chatId})');
      
      // Mark as syncing
      await _outboxRepository.markAsSyncing(msg.localId);
      
      // Send message based on type
      Message serverMessage;
      
      switch (msg.type) {
        case MessageType.text:
          serverMessage = await _messageRepository.sendMessage(
            chatId: msg.chatId,
            type: msg.type,
            content: msg.content,
            clientMessageId: msg.localId, // Use localId as clientMessageId for deduplication
          );
          break;
          
        case MessageType.audio:
          if (msg.localAudioPath == null) {
            throw Exception('Audio path is null for audio message');
          }
          serverMessage = await _messageRepository.sendAudioMessage(
            chatId: msg.chatId,
            audioPath: msg.localAudioPath!,
            clientMessageId: msg.localId,
          );
          break;
          
        case MessageType.image:
          // For images, we need localImagePath which isn't in PendingMessage currently
          // This would need to be added to PendingMessage if needed
          throw Exception('Image sync not implemented in outbox');
          
        case MessageType.file:
          // File sync not implemented in outbox - files are sent directly
          throw Exception('File sync not implemented in outbox');
      }
      
      // Mark as synced (this also removes from outbox)
      await _outboxRepository.markAsSynced(msg.localId, serverMessage.id);
      
      print('[OUTBOX_SYNC] Message ${msg.localId} synced successfully -> ${serverMessage.id}');
      
      // Notify UI about sync success
      if (onMessageSynced != null) {
        onMessageSynced!(msg.localId, serverMessage.id, serverMessage.status);
      }
      
      return true;
      
    } catch (e) {
      print('[OUTBOX_SYNC] Failed to sync message ${msg.localId}: $e');
      
      // Mark as failed with error message
      await _outboxRepository.markAsFailed(
        msg.localId, 
        'Sync failed: ${e.toString()}'
      );
      
      // Notify UI about failure
      if (onMessageFailed != null) {
        onMessageFailed!(msg.localId, e.toString());
      }
      
      return false;
    }
  }
  
  /// Get current sync status
  bool get isSyncing => _isSyncing;
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }
}
