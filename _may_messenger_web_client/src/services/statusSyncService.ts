import { messageApi } from '../api/messageApi';
import { MessageStatus } from '../types/chat';

/**
 * Service for syncing message status when SignalR is unavailable
 */
class StatusSyncService {
  private pollTimer: number | null = null;
  private lastSync: Date | null = null;
  private isPolling = false;

  /**
   * Start polling for status updates
   */
  startPolling(
    chatId: string,
    onStatusUpdate: (messageId: string, status: MessageStatus) => void,
    interval = 5000
  ): void {
    if (this.isPolling) {
      console.log('[SYNC] Already polling, ignoring start request');
      return;
    }

    console.log('[SYNC] Starting status polling for chat:', chatId);
    this.isPolling = true;
    this.lastSync = new Date(Date.now() - 5 * 60 * 1000); // Start from 5 minutes ago

    this.pollTimer = window.setInterval(async () => {
      try {
        await this.pollStatusUpdates(chatId, onStatusUpdate);
      } catch (error) {
        console.error('[SYNC] Polling error:', error);
      }
    }, interval);
  }

  /**
   * Poll for status updates
   */
  private async pollStatusUpdates(
    chatId: string,
    onStatusUpdate: (messageId: string, status: MessageStatus) => void
  ): Promise<void> {
    try {
      const updates = await messageApi.getStatusUpdates(chatId, this.lastSync || undefined);

      if (updates && updates.length > 0) {
        console.log(`[SYNC] Received ${updates.length} status updates via polling`);

        for (const update of updates) {
          try {
            const messageId = update.messageId;
            const status = update.status as MessageStatus;
            onStatusUpdate(messageId, status);
          } catch (error) {
            console.error('[SYNC] Failed to process status update:', error);
          }
        }
      }

      this.lastSync = new Date();
    } catch (error) {
      console.error('[SYNC] Failed to poll status updates:', error);
    }
  }

  /**
   * Stop polling
   */
  stopPolling(): void {
    if (this.pollTimer) {
      console.log('[SYNC] Stopping status polling');
      window.clearInterval(this.pollTimer);
      this.pollTimer = null;
      this.isPolling = false;
    }
  }

  /**
   * Check if currently polling
   */
  get polling(): boolean {
    return this.isPolling;
  }

  /**
   * Manually trigger a sync (useful after reconnection)
   */
  async syncNow(
    chatId: string,
    onStatusUpdate: (messageId: string, status: MessageStatus) => void
  ): Promise<void> {
    console.log('[SYNC] Manual sync triggered for chat:', chatId);
    await this.pollStatusUpdates(chatId, onStatusUpdate);
  }

  dispose(): void {
    this.stopPolling();
  }
}

export const statusSyncService = new StatusSyncService();

