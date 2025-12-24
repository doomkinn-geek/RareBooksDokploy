import { indexedDBStorage, PendingMessage } from '../services/indexedDBStorage';
import { Message, MessageType, MessageStatus } from '../types/chat';
import { uuidv4 } from '../utils/uuid';

export class OutboxRepository {
  /**
   * Add a new message to the outbox queue
   */
  async addToOutbox(
    chatId: string,
    type: MessageType,
    content?: string,
    localAudioPath?: string
  ): Promise<PendingMessage> {
    const pendingMessage: PendingMessage = {
      localId: uuidv4(),
      chatId,
      type,
      content,
      localAudioPath,
      syncState: 'localOnly',
      createdAt: new Date().toISOString(),
      retryCount: 0,
    };

    await indexedDBStorage.addPendingMessage(pendingMessage);
    console.log('[OUTBOX] Added message to outbox:', pendingMessage.localId);

    return pendingMessage;
  }

  /**
   * Get all pending messages for a specific chat
   */
  async getPendingMessagesForChat(chatId: string): Promise<PendingMessage[]> {
    return await indexedDBStorage.getPendingMessagesForChat(chatId);
  }

  /**
   * Get all pending messages across all chats
   */
  async getAllPendingMessages(): Promise<PendingMessage[]> {
    return await indexedDBStorage.getAllPendingMessages();
  }

  /**
   * Get a specific pending message by local ID
   */
  async getPendingMessageById(localId: string): Promise<PendingMessage | null> {
    return await indexedDBStorage.getPendingMessage(localId);
  }

  /**
   * Update a pending message
   */
  async updatePendingMessage(message: PendingMessage): Promise<void> {
    await indexedDBStorage.updatePendingMessage(message);
    console.log('[OUTBOX] Updated message:', message.localId, 'state:', message.syncState);
  }

  /**
   * Mark message as syncing
   */
  async markAsSyncing(localId: string): Promise<void> {
    const message = await this.getPendingMessageById(localId);
    if (message) {
      message.syncState = 'syncing';
      await this.updatePendingMessage(message);
    }
  }

  /**
   * Mark message as synced and associate with server ID
   */
  async markAsSynced(localId: string, serverId: string): Promise<void> {
    const message = await this.getPendingMessageById(localId);
    if (message) {
      message.syncState = 'synced';
      message.serverId = serverId;
      await this.updatePendingMessage(message);
    }
  }

  /**
   * Mark message as failed with error message
   */
  async markAsFailed(localId: string, errorMessage: string): Promise<void> {
    const message = await this.getPendingMessageById(localId);
    if (message) {
      message.syncState = 'failed';
      message.errorMessage = errorMessage;
      message.retryCount += 1;
      await this.updatePendingMessage(message);
    }
  }

  /**
   * Remove a pending message from outbox (after successful sync)
   */
  async removePendingMessage(localId: string): Promise<void> {
    await indexedDBStorage.removePendingMessage(localId);
    console.log('[OUTBOX] Removed message from outbox:', localId);
  }

  /**
   * Get messages that need to be retried (failed messages)
   */
  async getFailedMessages(): Promise<PendingMessage[]> {
    const allPending = await this.getAllPendingMessages();
    return allPending.filter((msg) => msg.syncState === 'failed');
  }

  /**
   * Get messages that are currently syncing
   */
  async getSyncingMessages(): Promise<PendingMessage[]> {
    const allPending = await this.getAllPendingMessages();
    return allPending.filter((msg) => msg.syncState === 'syncing');
  }

  /**
   * Retry a failed message
   */
  async retryMessage(localId: string): Promise<void> {
    const message = await this.getPendingMessageById(localId);
    if (message && message.syncState === 'failed') {
      message.syncState = 'localOnly';
      message.errorMessage = undefined;
      await this.updatePendingMessage(message);
      console.log('[OUTBOX] Message marked for retry:', localId);
    }
  }

  /**
   * Clear all synced messages from outbox (cleanup)
   */
  async clearSyncedMessages(): Promise<void> {
    const allPending = await this.getAllPendingMessages();
    for (const msg of allPending) {
      if (msg.syncState === 'synced') {
        await this.removePendingMessage(msg.localId);
      }
    }
  }

  /**
   * Get all pending messages (alias for getAllPendingMessages)
   */
  async getAllPending(): Promise<PendingMessage[]> {
    return await this.getAllPendingMessages();
  }

  /**
   * Clear all messages from outbox
   */
  async clearAll(): Promise<void> {
    const allPending = await this.getAllPendingMessages();
    for (const msg of allPending) {
      await this.removePendingMessage(msg.localId);
    }
    console.log('[OUTBOX] Cleared all messages');
  }

  /**
   * Convert PendingMessage to Message for UI display
   */
  toMessage(pending: PendingMessage, currentUserId: string, currentUserName: string): Message {
    return {
      id: pending.serverId || pending.localId,
      chatId: pending.chatId,
      senderId: currentUserId,
      senderName: currentUserName,
      type: pending.type,
      content: pending.content,
      filePath: pending.localAudioPath,
      status: this.mapSyncStateToMessageStatus(pending.syncState),
      createdAt: pending.createdAt,
      localId: pending.localId,
      isLocalOnly: pending.syncState !== 'synced',
    };
  }

  private mapSyncStateToMessageStatus(syncState: string): MessageStatus {
    switch (syncState) {
      case 'localOnly':
      case 'syncing':
        return MessageStatus.Sending;
      case 'synced':
        return MessageStatus.Sent;
      case 'failed':
        return MessageStatus.Failed;
      default:
        return MessageStatus.Sending;
    }
  }
}

export const outboxRepository = new OutboxRepository();

