/**
 * Browser Notification Service
 * Handles requesting permissions and showing native browser notifications
 */

export type NotificationPermission = 'default' | 'granted' | 'denied';

export interface NotificationOptions {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  tag?: string;
  data?: Record<string, unknown>;
  onClick?: () => void;
}

class NotificationService {
  private static instance: NotificationService;
  private permission: NotificationPermission = 'default';
  private currentChatId: string | null = null;

  private constructor() {
    this.permission = this.getPermissionStatus();
  }

  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }

  /**
   * Check if notifications are supported
   */
  isSupported(): boolean {
    return 'Notification' in window;
  }

  /**
   * Get current permission status
   */
  getPermissionStatus(): NotificationPermission {
    if (!this.isSupported()) {
      return 'denied';
    }
    return Notification.permission as NotificationPermission;
  }

  /**
   * Request notification permission from user
   */
  async requestPermission(): Promise<NotificationPermission> {
    if (!this.isSupported()) {
      console.warn('[Notifications] Not supported in this browser');
      return 'denied';
    }

    if (this.permission === 'granted') {
      return 'granted';
    }

    try {
      const permission = await Notification.requestPermission();
      this.permission = permission as NotificationPermission;
      console.log('[Notifications] Permission:', permission);
      return this.permission;
    } catch (error) {
      console.error('[Notifications] Permission request failed:', error);
      return 'denied';
    }
  }

  /**
   * Set the currently open chat (to suppress notifications for it)
   */
  setCurrentChat(chatId: string | null): void {
    this.currentChatId = chatId;
    console.log('[Notifications] Current chat set to:', chatId);
  }

  /**
   * Show a browser notification
   */
  async show(options: NotificationOptions): Promise<void> {
    // Don't show notification if user is currently in this chat
    if (options.tag && options.tag === this.currentChatId) {
      console.log('[Notifications] User in current chat, not showing notification');
      return;
    }

    if (!this.isSupported()) {
      console.warn('[Notifications] Not supported');
      return;
    }

    if (this.permission !== 'granted') {
      console.warn('[Notifications] Permission not granted');
      return;
    }

    // Check if page is visible (don't show notification if user is already viewing)
    if (document.visibilityState === 'visible' && options.tag === this.currentChatId) {
      console.log('[Notifications] Page visible, not showing notification');
      return;
    }

    try {
      const notification = new Notification(options.title, {
        body: options.body,
        icon: options.icon || '/icon-192.png',
        badge: options.badge || '/icon-96.png',
        tag: options.tag,
        data: options.data,
        requireInteraction: false,
        silent: false,
      });

      if (options.onClick) {
        notification.onclick = () => {
          options.onClick?.();
          notification.close();
          window.focus();
        };
      }

      // Auto-close after 10 seconds
      setTimeout(() => {
        notification.close();
      }, 10000);
    } catch (error) {
      console.error('[Notifications] Show failed:', error);
    }
  }

  /**
   * Show notification for a new message
   */
  async showMessageNotification(
    chatTitle: string,
    messageBody: string,
    chatId: string,
    onOpen?: () => void
  ): Promise<void> {
    await this.show({
      title: chatTitle,
      body: messageBody,
      tag: chatId,
      data: { chatId },
      onClick: onOpen,
    });
  }
}

export const notificationService = NotificationService.getInstance();

