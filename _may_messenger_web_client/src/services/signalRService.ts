import * as signalR from '@microsoft/signalr';
import { HUB_URL } from '../utils/constants';
import { Message, MessageStatus } from '../types/chat';

type MessageCallback = (message: Message) => void;
type MessageStatusCallback = (messageId: string, status: MessageStatus) => void;
type TypingCallback = (userId: string, userName: string, isTyping: boolean) => void;

class SignalRService {
  private connection: signalR.HubConnection | null = null;
  private messageCallbacks: MessageCallback[] = [];
  private messageStatusCallbacks: MessageStatusCallback[] = [];
  private typingCallbacks: TypingCallback[] = [];

  async connect(token: string): Promise<void> {
    if (this.connection?.state === signalR.HubConnectionState.Connected) {
      console.log('[SignalR] Already connected');
      return;
    }

    this.connection = new signalR.HubConnectionBuilder()
      .withUrl(HUB_URL, {
        accessTokenFactory: () => token,
        transport: signalR.HttpTransportType.WebSockets,
      })
      .withAutomaticReconnect()
      .configureLogging(signalR.LogLevel.Information)
      .build();

    // Set up event handlers
    this.connection.on('ReceiveMessage', (message: Message) => {
      console.log('[MSG_RECV] Message received via SignalR:', message.id, 'for chat', message.chatId);
      
      // Send delivery confirmation (skip for own messages)
      const currentUserId = localStorage.getItem('userId'); // Assuming userId is stored
      const isFromMe = currentUserId && message.senderId === currentUserId;
      
      if (!isFromMe) {
        this.markMessageAsDelivered(message.id, message.chatId)
          .then(() => {
            console.log('[MSG_RECV] Delivery confirmation sent for message:', message.id);
          })
          .catch((error) => {
            console.error('[MSG_RECV] Failed to send delivery confirmation:', error);
            // Retry after a delay
            setTimeout(() => {
              this.markMessageAsDelivered(message.id, message.chatId)
                .then(() => console.log('[MSG_RECV] Delivery confirmation sent (retry):', message.id))
                .catch((err) => console.error('[MSG_RECV] Delivery confirmation retry failed:', err));
            }, 2000);
          });
      } else {
        console.log('[MSG_RECV] Skipping delivery confirmation for own message:', message.id);
      }
      
      this.messageCallbacks.forEach((callback) => callback(message));
    });

    this.connection.on('MessageStatusUpdated', (messageId: string, status: MessageStatus) => {
      console.log('[SignalR] MessageStatusUpdated', messageId, status);
      this.messageStatusCallbacks.forEach((callback) => callback(messageId, status));
    });

    this.connection.on('UserTyping', (userId: string, userName: string, isTyping: boolean) => {
      console.log('[SignalR] UserTyping', userId, userName, isTyping);
      this.typingCallbacks.forEach((callback) => callback(userId, userName, isTyping));
    });

    this.connection.onreconnecting((error) => {
      console.log('[SignalR] Reconnecting...', error);
    });

    this.connection.onreconnected((connectionId) => {
      console.log('[SignalR] Reconnected', connectionId);
    });

    this.connection.onclose((error) => {
      console.log('[SignalR] Connection closed', error);
    });

    try {
      await this.connection.start();
      console.log('[SignalR] Connected', this.connection.connectionId);
    } catch (error) {
      console.error('[SignalR] Connection failed', error);
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

  async joinChat(chatId: string): Promise<void> {
    if (!this.connection) {
      throw new Error('SignalR connection not established');
    }
    await this.connection.invoke('JoinChat', chatId);
    console.log('[SignalR] Joined chat', chatId);
  }

  async leaveChat(chatId: string): Promise<void> {
    if (!this.connection) {
      throw new Error('SignalR connection not established');
    }
    await this.connection.invoke('LeaveChat', chatId);
    console.log('[SignalR] Left chat', chatId);
  }

  async markMessageAsDelivered(messageId: string, chatId: string): Promise<void> {
    if (!this.connection) {
      throw new Error('SignalR connection not established');
    }
    await this.connection.invoke('MessageDelivered', messageId, chatId);
    console.log('[SignalR] Message marked as delivered:', messageId);
  }

  async markMessageAsRead(messageId: string, chatId: string): Promise<void> {
    if (!this.connection) {
      throw new Error('SignalR connection not established');
    }
    await this.connection.invoke('MessageRead', messageId, chatId);
  }

  async sendTypingIndicator(chatId: string, isTyping: boolean): Promise<void> {
    if (!this.connection) {
      throw new Error('SignalR connection not established');
    }
    await this.connection.invoke('TypingIndicator', chatId, isTyping);
  }

  onMessage(callback: MessageCallback): () => void {
    this.messageCallbacks.push(callback);
    return () => {
      this.messageCallbacks = this.messageCallbacks.filter((cb) => cb !== callback);
    };
  }

  onMessageStatus(callback: MessageStatusCallback): () => void {
    this.messageStatusCallbacks.push(callback);
    return () => {
      this.messageStatusCallbacks = this.messageStatusCallbacks.filter((cb) => cb !== callback);
    };
  }

  onTyping(callback: TypingCallback): () => void {
    this.typingCallbacks.push(callback);
    return () => {
      this.typingCallbacks = this.typingCallbacks.filter((cb) => cb !== callback);
    };
  }

  get isConnected(): boolean {
    return this.connection?.state === signalR.HubConnectionState.Connected;
  }
}

export const signalRService = new SignalRService();
