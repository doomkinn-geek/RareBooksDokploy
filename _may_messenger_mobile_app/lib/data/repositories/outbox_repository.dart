import 'package:uuid/uuid.dart';
import '../datasources/local_datasource.dart';
import '../models/message_model.dart';

enum SyncState {
  localOnly,
  syncing,
  synced,
  failed,
}

class PendingMessage {
  final String localId;
  final String chatId;
  final MessageType type;
  final String? content;
  final String? localAudioPath;
  final String? localImagePath;
  final String? localFilePath;
  final String? originalFileName;
  final String? replyToMessageId;
  final SyncState syncState;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final String? serverId; // Set after successful sync

  PendingMessage({
    required this.localId,
    required this.chatId,
    required this.type,
    this.content,
    this.localAudioPath,
    this.localImagePath,
    this.localFilePath,
    this.originalFileName,
    this.replyToMessageId,
    required this.syncState,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    this.serverId,
  });

  PendingMessage copyWith({
    String? localId,
    String? chatId,
    MessageType? type,
    String? content,
    String? localAudioPath,
    String? localImagePath,
    String? localFilePath,
    String? originalFileName,
    String? replyToMessageId,
    SyncState? syncState,
    DateTime? createdAt,
    int? retryCount,
    String? errorMessage,
    String? serverId,
  }) {
    return PendingMessage(
      localId: localId ?? this.localId,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      content: content ?? this.content,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localImagePath: localImagePath ?? this.localImagePath,
      localFilePath: localFilePath ?? this.localFilePath,
      originalFileName: originalFileName ?? this.originalFileName,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      serverId: serverId ?? this.serverId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'chatId': chatId,
      'type': type.index,
      'content': content,
      'localAudioPath': localAudioPath,
      'localImagePath': localImagePath,
      'localFilePath': localFilePath,
      'originalFileName': originalFileName,
      'replyToMessageId': replyToMessageId,
      'syncState': syncState.index,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'serverId': serverId,
    };
  }

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    return PendingMessage(
      localId: json['localId'],
      chatId: json['chatId'],
      type: MessageType.values[json['type']],
      content: json['content'],
      localAudioPath: json['localAudioPath'],
      localImagePath: json['localImagePath'],
      localFilePath: json['localFilePath'],
      originalFileName: json['originalFileName'],
      replyToMessageId: json['replyToMessageId'],
      syncState: SyncState.values[json['syncState']],
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
      serverId: json['serverId'],
    );
  }

  /// Convert to Message for UI display
  Message toMessage(String senderId, String senderName) {
    return Message(
      id: serverId ?? localId, // Use server ID if available, otherwise local ID
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      localAudioPath: localAudioPath,
      localImagePath: localImagePath,
      filePath: null,
      originalFileName: originalFileName,
      status: _mapSyncStateToMessageStatus(),
      createdAt: createdAt,
      isLocalOnly: syncState != SyncState.synced,
      localId: localId,
    );
  }

  MessageStatus _mapSyncStateToMessageStatus() {
    switch (syncState) {
      case SyncState.localOnly:
      case SyncState.syncing:
        return MessageStatus.sending;
      case SyncState.synced:
        return MessageStatus.sent;
      case SyncState.failed:
        return MessageStatus.failed;
    }
  }
}

class OutboxRepository {
  final LocalDataSource _localDataSource;
  final _uuid = const Uuid();
  bool _isInitialized = false;

  OutboxRepository(this._localDataSource);
  
  /// Initialize repository with corruption recovery
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('[OUTBOX] Initializing with corruption recovery...');
      
      // Try to load all pending messages to check for corruption
      final messages = await getAllPendingMessages();
      print('[OUTBOX] Loaded ${messages.length} pending messages successfully');
      
      // Clean up any stuck "syncing" messages (likely from app crash)
      int resetCount = 0;
      for (final msg in messages) {
        if (msg.syncState == SyncState.syncing) {
          // Reset to localOnly so they can be retried
          await updatePendingMessage(
            msg.copyWith(syncState: SyncState.localOnly),
          );
          resetCount++;
        }
      }
      
      if (resetCount > 0) {
        print('[OUTBOX] Reset $resetCount stuck "syncing" messages');
      }
      
      _isInitialized = true;
      print('[OUTBOX] Initialization complete');
    } catch (e, stackTrace) {
      print('[OUTBOX] Corruption detected during initialization: $e');
      print('[OUTBOX] Stack trace: $stackTrace');
      
      // Attempt recovery by clearing corrupted data
      try {
        await _localDataSource.clearAllPendingMessages();
        print('[OUTBOX] Cleared corrupted outbox data');
        _isInitialized = true;
      } catch (clearError) {
        print('[OUTBOX] Failed to clear corrupted data: $clearError');
        // Continue anyway, app should still work
        _isInitialized = true;
      }
    }
  }

  /// Add a new message to the outbox queue
  /// Uses atomic operation to prevent corruption
  /// Supports all message types: text, audio, image, file
  Future<PendingMessage> addToOutbox({
    required String chatId,
    required MessageType type,
    String? content,
    String? localAudioPath,
    String? localImagePath,
    String? localFilePath,
    String? originalFileName,
    String? replyToMessageId,
  }) async {
    await initialize(); // Ensure initialized before operations
    
    final pendingMessage = PendingMessage(
      localId: _uuid.v4(),
      chatId: chatId,
      type: type,
      content: content,
      localAudioPath: localAudioPath,
      localImagePath: localImagePath,
      localFilePath: localFilePath,
      originalFileName: originalFileName,
      replyToMessageId: replyToMessageId,
      syncState: SyncState.localOnly,
      createdAt: DateTime.now(),
    );

    try {
      // Atomic operation: add to outbox
      await _localDataSource.addPendingMessage(pendingMessage);
      print('[OUTBOX] Added ${type.name} message to outbox: ${pendingMessage.localId}');
      
      return pendingMessage;
    } catch (e, stackTrace) {
      print('[OUTBOX] Error adding message to outbox: $e');
      print('[OUTBOX] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all pending messages for a specific chat
  Future<List<PendingMessage>> getPendingMessagesForChat(String chatId) async {
    return await _localDataSource.getPendingMessagesForChat(chatId);
  }

  /// Get all pending messages across all chats
  Future<List<PendingMessage>> getAllPendingMessages() async {
    return await _localDataSource.getAllPendingMessages();
  }

  /// Update a pending message (e.g., change sync state, add server ID)
  /// Uses atomic operation to prevent corruption
  Future<void> updatePendingMessage(PendingMessage message) async {
    try {
      await _localDataSource.updatePendingMessage(message);
      print('[OUTBOX] Updated message: ${message.localId}, state: ${message.syncState}');
    } catch (e, stackTrace) {
      print('[OUTBOX] Error updating message: $e');
      print('[OUTBOX] Stack trace: $stackTrace');
      // Don't rethrow - this is not critical
    }
  }

  /// Mark message as syncing
  Future<void> markAsSyncing(String localId) async {
    final message = await _localDataSource.getPendingMessageById(localId);
    if (message != null) {
      await updatePendingMessage(
        message.copyWith(syncState: SyncState.syncing),
      );
    }
  }

  /// Mark message as synced and associate with server ID
  /// IMMEDIATELY removes from outbox after successful sync (no need to keep synced messages)
  Future<void> markAsSynced(String localId, String serverId) async {
    final message = await _localDataSource.getPendingMessageById(localId);
    if (message != null) {
      // Immediately remove from outbox instead of keeping synced messages
      // This simplifies logic and prevents raceConditions
      await removePendingMessage(localId);
      print('[OUTBOX] Message synced and removed immediately: $localId -> $serverId');
    }
  }

  /// Mark message as failed with error message
  Future<void> markAsFailed(String localId, String errorMessage) async {
    final message = await _localDataSource.getPendingMessageById(localId);
    if (message != null) {
      await updatePendingMessage(
        message.copyWith(
          syncState: SyncState.failed,
          errorMessage: errorMessage,
          retryCount: message.retryCount + 1,
        ),
      );
    }
  }

  /// Remove a pending message from outbox (after successful sync)
  /// Uses atomic operation to prevent corruption
  Future<void> removePendingMessage(String localId) async {
    try {
      await _localDataSource.removePendingMessage(localId);
      print('[OUTBOX] Removed message from outbox: $localId');
    } catch (e, stackTrace) {
      print('[OUTBOX] Error removing message: $e');
      print('[OUTBOX] Stack trace: $stackTrace');
      // Don't rethrow - message might already be removed
    }
  }

  /// Get messages that need to be retried (failed messages)
  Future<List<PendingMessage>> getFailedMessages() async {
    final allPending = await getAllPendingMessages();
    return allPending.where((msg) => msg.syncState == SyncState.failed).toList();
  }

  /// Get messages that are currently syncing
  Future<List<PendingMessage>> getSyncingMessages() async {
    final allPending = await getAllPendingMessages();
    return allPending.where((msg) => msg.syncState == SyncState.syncing).toList();
  }

  /// Retry a failed message
  Future<void> retryMessage(String localId) async {
    final message = await _localDataSource.getPendingMessageById(localId);
    if (message != null && message.syncState == SyncState.failed) {
      await updatePendingMessage(
        message.copyWith(
          syncState: SyncState.localOnly,
          errorMessage: null,
        ),
      );
      print('[OUTBOX] Message marked for retry: $localId');
    }
  }

  /// Clear all synced messages from outbox (cleanup)
  /// NOTE: With immediate removal on sync, this should rarely find anything
  Future<void> clearSyncedMessages() async {
    final allPending = await getAllPendingMessages();
    int removedCount = 0;
    for (final msg in allPending) {
      if (msg.syncState == SyncState.synced) {
        await removePendingMessage(msg.localId);
        removedCount++;
      }
    }
    if (removedCount > 0) {
      print('[OUTBOX] Cleared $removedCount synced messages (should be rare with immediate removal)');
    }
  }
  
  /// Clean up old failed messages (older than 7 days)
  Future<void> cleanupOldFailedMessages() async {
    final allPending = await getAllPendingMessages();
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    int removedCount = 0;
    
    for (final msg in allPending) {
      if (msg.syncState == SyncState.failed && msg.createdAt.isBefore(cutoffDate)) {
        await removePendingMessage(msg.localId);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      print('[OUTBOX] Cleaned up $removedCount old failed messages');
    }
  }
  
  /// Get outbox statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
    };
  }
}

