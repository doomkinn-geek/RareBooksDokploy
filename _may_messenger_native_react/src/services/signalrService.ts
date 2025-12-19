import * as signalR from '@microsoft/signalr';
import { API_CONFIG, APP_CONFIG } from '../utils/constants';
import { Message, MessageStatus, SignalRMessage } from '../types';

class SignalRService {
  private connection: signalR.HubConnection | null = null;
  private token: string | null = null;
  private reconnectAttempt = 0;

  async connect(token: string): Promise<void> {
    this.token = token;
    
    this.connection = new signalR.HubConnectionBuilder()
      .withUrl(API_CONFIG.HUB_URL, {
        accessTokenFactory: () => token,
        transport: signalR.HttpTransportType.WebSockets,
      })
      .withAutomaticReconnect(APP_CONFIG.RECONNECT_DELAYS)
      .configureLogging(signalR.LogLevel.Information)
      .build();

    // Connection handlers
    this.connection.onclose((error) => {
      console.log('[SignalR] Connection closed:', error);
      this.reconnectAttempt = 0;
    });

    this.connection.onreconnecting((error) => {
      console.log('[SignalR] Reconnecting...', error);
      this.reconnectAttempt++;
    });

    this.connection.onreconnected((connectionId) => {
      console.log('[SignalR] Reconnected!', connectionId);
      this.reconnectAttempt = 0;
    });

    try {
      await this.connection.start();
      console.log('[SignalR] Connected successfully');
    } catch (error) {
      console.error('[SignalR] Failed to connect:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.connection) {
      await this.connection.stop();
      this.connection = null;
      console.log('[SignalR] Disconnected');
    }
  }

  isConnected(): boolean {
    return this.connection?.state === signalR.HubConnectionState.Connected;
  }

  async joinChat(chatId: string): Promise<void> {
    if (!this.isConnected()) {
      console.warn('[SignalR] Not connected, cannot join chat');
      return;
    }

    try {
      await this.connection?.invoke('JoinChat', chatId);
      console.log('[SignalR] Joined chat:', chatId);
    } catch (error) {
      console.error('[SignalR] Failed to join chat:', error);
    }
  }

  async leaveChat(chatId: string): Promise<void> {
    if (!this.isConnected()) {
      return;
    }

    try {
      await this.connection?.invoke('LeaveChat', chatId);
      console.log('[SignalR] Left chat:', chatId);
    } catch (error) {
      console.error('[SignalR] Failed to leave chat:', error);
    }
  }

  async sendTypingIndicator(chatId: string, isTyping: boolean): Promise<void> {
    if (!this.isConnected()) {
      return;
    }

    try {
      await this.connection?.invoke('TypingIndicator', chatId, isTyping);
    } catch (error) {
      // Silent fail for typing indicator
    }
  }

  async markMessageAsRead(messageId: string, chatId: string): Promise<void> {
    if (!this.isConnected()) {
      return;
    }

    try {
      await this.connection?.invoke('MessageRead', messageId, chatId);
      console.log('[SignalR] Message marked as read:', messageId);
    } catch (error) {
      console.error('[SignalR] Failed to mark as read:', error);
    }
  }

  // Event listeners
  onReceiveMessage(callback: (message: Message) => void): void {
    this.connection?.on('ReceiveMessage', (messageData: SignalRMessage) => {
      // Convert SignalR message to our Message type
      const message: Message = {
        id: messageData.id,
        chatId: messageData.chatId,
        senderId: messageData.senderId,
        senderName: messageData.senderName,
        type: messageData.type,
        content: messageData.content,
        filePath: messageData.filePath,
        status: messageData.status,
        createdAt: messageData.createdAt,
      };
      
      callback(message);
    });
  }

  onMessageStatusUpdated(callback: (messageId: string, status: MessageStatus) => void): void {
    this.connection?.on('MessageStatusUpdated', (messageId: string, statusIndex: number) => {
      const status = statusIndex as MessageStatus;
      callback(messageId, status);
    });
  }

  onUserTyping(callback: (userId: string, userName: string, isTyping: boolean) => void): void {
    this.connection?.on('UserTyping', callback);
  }

  onNewChatCreated(callback: () => void): void {
    this.connection?.on('NewChatCreated', callback);
  }

  onMessageDeleted(callback: (data: { messageId: string; chatId: string }) => void): void {
    this.connection?.on('MessageDeleted', callback);
  }

  onChatDeleted(callback: (data: { chatId: string }) => void): void {
    this.connection?.on('ChatDeleted', callback);
  }

  removeAllListeners(): void {
    this.connection?.off('ReceiveMessage');
    this.connection?.off('MessageStatusUpdated');
    this.connection?.off('UserTyping');
    this.connection?.off('NewChatCreated');
    this.connection?.off('MessageDeleted');
    this.connection?.off('ChatDeleted');
  }
}

export const signalrService = new SignalRService();

