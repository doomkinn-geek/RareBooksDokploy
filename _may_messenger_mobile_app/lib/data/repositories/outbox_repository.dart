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
      filePath: null,
      status: _mapSyncStateToMessageStatus(),
      createdAt: createdAt,
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

  OutboxRepository(this._localDataSource);

  /// Add a new message to the outbox queue
  Future<PendingMessage> addToOutbox({
    required String chatId,
    required MessageType type,
    String? content,
    String? localAudioPath,
  }) async {
    final pendingMessage = PendingMessage(
      localId: _uuid.v4(),
      chatId: chatId,
      type: type,
      content: content,
      localAudioPath: localAudioPath,
      syncState: SyncState.localOnly,
      createdAt: DateTime.now(),
    );

    await _localDataSource.addPendingMessage(pendingMessage);
    print('[OUTBOX] Added message to outbox: ${pendingMessage.localId}');
    
    return pendingMessage;
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
  Future<void> updatePendingMessage(PendingMessage message) async {
    await _localDataSource.updatePendingMessage(message);
    print('[OUTBOX] Updated message: ${message.localId}, state: ${message.syncState}');
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
  Future<void> markAsSynced(String localId, String serverId) async {
    final message = await _localDataSource.getPendingMessageById(localId);
    if (message != null) {
      await updatePendingMessage(
        message.copyWith(
          syncState: SyncState.synced,
          serverId: serverId,
        ),
      );
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
  Future<void> removePendingMessage(String localId) async {
    await _localDataSource.removePendingMessage(localId);
    print('[OUTBOX] Removed message from outbox: $localId');
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
  Future<void> clearSyncedMessages() async {
    final allPending = await getAllPendingMessages();
    for (final msg in allPending) {
      if (msg.syncState == SyncState.synced) {
        await removePendingMessage(msg.localId);
      }
    }
  }
}

