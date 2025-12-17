import { outboxRepository } from '../repositories/outboxRepository';
import { messageApi } from '../api/messageApi';
import { Message, MessageStatus, MessageType } from '../types/chat';
import { PendingMessage } from './indexedDBStorage';

/**
 * Background service for syncing pending messages from outbox
 */
class OfflineSyncService {
  private syncTimer: NodeJS.Timeout | null = null;
  private isSyncing = false;
  
  onMessageSynced?: (localId: string, serverId: string) => void;
  onMessageStatusUpdate?: (localId: string, status: MessageStatus) => void;

  /**
   * Start the background sync service
   */
  start(): void {
    console.log('[SYNC] Starting offline sync service');
    
    // Listen for online/offline events
    window.addEventListener('online', this.handleOnline);
    window.addEventListener('offline', this.handleOffline);
    
    // Periodic sync every 30 seconds
    this.syncTimer = setInterval(() => {
      this.syncNow();
    }, 30000);
    
    // Initial sync
    this.syncNow();
  }

  private handleOnline = (): void => {
    console.log('[SYNC] Network connected, triggering sync');
    this.syncNow();
  };

  private handleOffline = (): void => {
    console.log('[SYNC] Network disconnected');
  };

  /**
   * Manually trigger sync
   */
  async syncNow(): Promise<void> {
    if (this.isSyncing) {
      console.log('[SYNC] Already syncing, skipping');
      return;
    }
    
    this.isSyncing = true;
    
    try {
      // Check if online
      if (!navigator.onLine) {
        console.log('[SYNC] No network connection, skipping sync');
        return;
      }
      
      // Get all pending messages
      const pendingMessages = await outboxRepository.getAllPendingMessages();
      
      if (pendingMessages.length === 0) {
        console.log('[SYNC] No pending messages to sync');
        return;
      }
      
      console.log(`[SYNC] Syncing ${pendingMessages.length} pending messages`);
      
      for (const pending of pendingMessages) {
        // Skip messages that are currently syncing
        if (pending.syncState === 'syncing') {
          continue;
        }
        
        // Check if message should be retried (with exponential backoff)
        if (pending.syncState === 'failed') {
          const shouldRetry = this.shouldRetry(pending.retryCount, new Date(pending.createdAt));
          if (!shouldRetry) {
            console.log(`[SYNC] Skipping message ${pending.localId} (retry limit or cooldown)`);
            continue;
          }
        }
        
        // Attempt to sync message
        await this.syncMessage(pending);
      }
      
    } catch (error) {
      console.error('[SYNC] Sync error:', error);
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Sync a single pending message
   */
  private async syncMessage(pending: PendingMessage): Promise<void> {
    try {
      console.log(`[SYNC] Syncing message: ${pending.localId} (attempt ${pending.retryCount + 1})`);
      
      // Mark as syncing
      await outboxRepository.markAsSyncing(pending.localId);
      
      // Send to backend
      let serverMessage: Message;
      if (pending.type === MessageType.Text) {
        serverMessage = await messageApi.sendMessage({
          chatId: pending.chatId,
          type: pending.type,
          content: pending.content,
        });
      } else {
        // Audio messages need special handling
        // For now, mark as failed if we don't have the blob
        throw new Error('Audio message sync not implemented');
      }
      
      console.log(`[SYNC] Message synced successfully: ${pending.localId} -> ${serverMessage.id}`);
      
      // Mark as synced
      await outboxRepository.markAsSynced(pending.localId, serverMessage.id);
      
      // Notify listeners
      this.onMessageSynced?.(pending.localId, serverMessage.id);
      this.onMessageStatusUpdate?.(pending.localId, MessageStatus.Sent);
      
      // Clean up after successful sync (with delay)
      setTimeout(() => {
        outboxRepository.removePendingMessage(pending.localId);
      }, 120000); // 2 minutes
      
    } catch (error: any) {
      console.error(`[SYNC] Failed to sync message ${pending.localId}:`, error);
      
      // Mark as failed
      const errorMessage = error.response?.data?.message || error.message || 'Sync failed';
      await outboxRepository.markAsFailed(pending.localId, errorMessage);
      
      // Notify listeners
      this.onMessageStatusUpdate?.(pending.localId, MessageStatus.Failed);
    }
  }

  /**
   * Determine if a failed message should be retried (exponential backoff)
   */
  private shouldRetry(retryCount: number, createdAt: Date): boolean {
    const maxRetries = 10;
    
    if (retryCount >= maxRetries) {
      return false;
    }
    
    // Exponential backoff: 10s, 20s, 40s, 80s, 160s, ...
    const backoffSeconds = 10 * Math.pow(2, retryCount);
    const nextRetryTime = new Date(createdAt.getTime() + backoffSeconds * 1000);
    
    return new Date() > nextRetryTime;
  }

  /**
   * Retry a specific failed message immediately
   */
  async retryMessage(localId: string): Promise<void> {
    console.log('[SYNC] Manual retry requested for message:', localId);
    
    const message = await outboxRepository.getPendingMessageById(localId);
    if (!message) {
      console.log('[SYNC] Message not found:', localId);
      return;
    }
    
    if (message.syncState !== 'failed') {
      console.log('[SYNC] Message is not in failed state:', localId);
      return;
    }
    
    // Reset to local-only state
    await outboxRepository.retryMessage(localId);
    
    // Trigger sync
    await this.syncMessage(message);
  }

  /**
   * Get statistics about pending messages
   */
  async getStats(): Promise<{
    total: number;
    pending: number;
    syncing: number;
    failed: number;
    synced: number;
  }> {
    const all = await outboxRepository.getAllPendingMessages();
    return {
      total: all.length,
      pending: all.filter((m) => m.syncState === 'localOnly').length,
      syncing: all.filter((m) => m.syncState === 'syncing').length,
      failed: all.filter((m) => m.syncState === 'failed').length,
      synced: all.filter((m) => m.syncState === 'synced').length,
    };
  }

  /**
   * Stop the sync service
   */
  stop(): void {
    console.log('[SYNC] Stopping offline sync service');
    
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
      this.syncTimer = null;
    }
    
    window.removeEventListener('online', this.handleOnline);
    window.removeEventListener('offline', this.handleOffline);
  }

  dispose(): void {
    this.stop();
  }
}

export const offlineSyncService = new OfflineSyncService();

