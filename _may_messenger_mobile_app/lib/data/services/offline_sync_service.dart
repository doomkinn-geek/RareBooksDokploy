import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/outbox_repository.dart';
import '../repositories/message_repository.dart';
import '../models/message_model.dart';

/// Background service for syncing pending messages from outbox
class OfflineSyncService {
  final OutboxRepository _outboxRepository;
  final MessageRepository _messageRepository;
  final Connectivity _connectivity = Connectivity();
  
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  Function(String localId, String serverId)? onMessageSynced;
  Function(String localId, MessageStatus status)? onMessageStatusUpdate;

  OfflineSyncService(this._outboxRepository, this._messageRepository);

  /// Start the background sync service
  Future<void> start() async {
    print('[SYNC] Starting offline sync service');
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print('[SYNC] Network connected, triggering sync');
        syncNow();
      } else {
        print('[SYNC] Network disconnected');
      }
    });
    
    // Periodic sync every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncNow();
    });
    
    // Initial sync
    syncNow();
  }

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (_isSyncing) {
      print('[SYNC] Already syncing, skipping');
      return;
    }
    
    _isSyncing = true;
    
    try {
      // Check if online
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('[SYNC] No network connection, skipping sync');
        return;
      }
      
      // Get all pending messages
      final pendingMessages = await _outboxRepository.getAllPendingMessages();
      
      if (pendingMessages.isEmpty) {
        print('[SYNC] No pending messages to sync');
        return;
      }
      
      print('[SYNC] Syncing ${pendingMessages.length} pending messages');
      
      for (final pending in pendingMessages) {
        // Skip messages that are currently syncing
        if (pending.syncState == SyncState.syncing) {
          continue;
        }
        
        // Check if message should be retried (with exponential backoff)
        if (pending.syncState == SyncState.failed) {
          final shouldRetry = _shouldRetry(pending.retryCount, pending.createdAt);
          if (!shouldRetry) {
            print('[SYNC] Skipping message ${pending.localId} (retry limit or cooldown)');
            continue;
          }
        }
        
        // Attempt to sync message
        await _syncMessage(pending);
      }
      
    } catch (e) {
      print('[SYNC] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single pending message
  /// Supports all message types: text, audio, image, file
  Future<void> _syncMessage(PendingMessage pending) async {
    try {
      print('[SYNC] Syncing ${pending.type.name} message: ${pending.localId} (attempt ${pending.retryCount + 1})');
      
      // Mark as syncing
      await _outboxRepository.markAsSyncing(pending.localId);
      
      // Send to backend based on message type
      Message serverMessage;
      
      switch (pending.type) {
        case MessageType.text:
          serverMessage = await _messageRepository.sendMessage(
            chatId: pending.chatId,
            type: pending.type,
            content: pending.content,
            replyToMessageId: pending.replyToMessageId,
          );
          break;
          
        case MessageType.audio:
          if (pending.localAudioPath == null) {
            throw Exception('Audio path is null for audio message');
          }
          serverMessage = await _messageRepository.sendAudioMessage(
            chatId: pending.chatId,
            audioPath: pending.localAudioPath!,
            replyToMessageId: pending.replyToMessageId,
          );
          break;
          
        case MessageType.image:
          if (pending.localImagePath == null) {
            throw Exception('Image path is null for image message');
          }
          serverMessage = await _messageRepository.sendImageMessage(
            chatId: pending.chatId,
            imagePath: pending.localImagePath!,
            replyToMessageId: pending.replyToMessageId,
          );
          break;
          
        case MessageType.file:
          if (pending.localFilePath == null) {
            throw Exception('File path is null for file message');
          }
          serverMessage = await _messageRepository.sendFileMessage(
            chatId: pending.chatId,
            filePath: pending.localFilePath!,
            fileName: pending.originalFileName ?? 'file',
            replyToMessageId: pending.replyToMessageId,
          );
          break;
          
        case MessageType.poll:
          throw Exception('Poll messages should not be in offline sync');
          
        case MessageType.video:
          throw Exception('Video messages should not be in offline sync');
      }
      
      print('[SYNC] Message synced successfully: ${pending.localId} -> ${serverMessage.id}');
      
      // Mark as synced
      await _outboxRepository.markAsSynced(pending.localId, serverMessage.id);
      
      // Notify listeners
      onMessageSynced?.call(pending.localId, serverMessage.id);
      onMessageStatusUpdate?.call(pending.localId, MessageStatus.sent);
      
      // Clean up after successful sync (with delay)
      Future.delayed(const Duration(minutes: 2), () {
        _outboxRepository.removePendingMessage(pending.localId);
      });
      
    } catch (e) {
      print('[SYNC] Failed to sync message ${pending.localId}: $e');
      
      // Mark as failed
      await _outboxRepository.markAsFailed(pending.localId, e.toString());
      
      // Notify listeners
      onMessageStatusUpdate?.call(pending.localId, MessageStatus.failed);
    }
  }

  /// Determine if a failed message should be retried (exponential backoff)
  bool _shouldRetry(int retryCount, DateTime createdAt) {
    const maxRetries = 10;
    
    if (retryCount >= maxRetries) {
      return false;
    }
    
    // Exponential backoff: 10s, 20s, 40s, 80s, 160s, ...
    final backoffSeconds = 10 * (1 << retryCount);
    final nextRetryTime = createdAt.add(Duration(seconds: backoffSeconds));
    
    return DateTime.now().isAfter(nextRetryTime);
  }

  /// Retry a specific failed message immediately
  Future<void> retryMessage(String localId) async {
    print('[SYNC] Manual retry requested for message: $localId');
    
    final message = await _outboxRepository.getPendingMessageById(localId);
    if (message == null) {
      print('[SYNC] Message not found: $localId');
      return;
    }
    
    if (message.syncState != SyncState.failed) {
      print('[SYNC] Message is not in failed state: $localId');
      return;
    }
    
    // Reset to local-only state
    await _outboxRepository.retryMessage(localId);
    
    // Trigger sync
    await _syncMessage(message);
  }

  /// Get statistics about pending messages
  Future<Map<String, int>> getStats() async {
    final all = await _outboxRepository.getAllPendingMessages();
    return {
      'total': all.length,
      'pending': all.where((m) => m.syncState == SyncState.localOnly).length,
      'syncing': all.where((m) => m.syncState == SyncState.syncing).length,
      'failed': all.where((m) => m.syncState == SyncState.failed).length,
      'synced': all.where((m) => m.syncState == SyncState.synced).length,
    };
  }

  /// Stop the sync service
  void stop() {
    print('[SYNC] Stopping offline sync service');
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  void dispose() {
    stop();
  }
}

