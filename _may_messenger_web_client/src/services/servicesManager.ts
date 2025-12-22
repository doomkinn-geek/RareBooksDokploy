/**
 * Services Manager - централизованная инициализация и управление всеми сервисами
 */

import { signalRService } from './signalRService';
import TypingIndicatorService from './typingIndicatorService';
import { eventQueueService, MessageReceivedEvent, MessageSentEvent, StatusUpdateEvent, UserStatusChangedEvent, TypingIndicatorEvent } from './eventQueueService';
import { connectivityService } from './connectivityService';

class ServicesManager {
  private typingIndicatorService: TypingIndicatorService | null = null;
  private isInitialized = false;

  /**
   * Инициализация всех сервисов приложения
   */
  async initialize(token: string): Promise<void> {
    if (this.isInitialized) {
      console.log('[ServicesManager] Already initialized');
      return;
    }

    console.log('[ServicesManager] Initializing services...');

    try {
      // 1. Инициализация TypingIndicatorService
      this.typingIndicatorService = new TypingIndicatorService(
        async (chatId: string, isTyping: boolean) => {
          await signalRService.sendTypingIndicator(chatId, isTyping);
        }
      );

      // 2. Подключение EventQueueService обработчиков
      this.setupEventQueueHandlers();

      // 3. Подключение SignalR
      await signalRService.connect(token);

      // 4. Настройка ConnectivityService
      this.setupConnectivityHandlers();

      this.isInitialized = true;
      console.log('[ServicesManager] Services initialized successfully');
    } catch (error) {
      console.error('[ServicesManager] Initialization failed:', error);
      throw error;
    }
  }

  /**
   * Настройка обработчиков EventQueueService
   */
  private setupEventQueueHandlers(): void {
    // Обработчик получения сообщения
    eventQueueService.registerHandler('MessageReceived', (event) => {
      const msgEvent = event as MessageReceivedEvent;
      console.log('[ServicesManager] Processing MessageReceived:', msgEvent.messageData.id);
      // Дополнительная обработка, если нужна
    });

    // Обработчик отправки сообщения
    eventQueueService.registerHandler('MessageSent', (event) => {
      const msgEvent = event as MessageSentEvent;
      console.log('[ServicesManager] Processing MessageSent:', msgEvent.messageId);
      // Дополнительная обработка, если нужна
    });

    // Обработчик обновления статуса
    eventQueueService.registerHandler('StatusUpdate', (event) => {
      const statusEvent = event as StatusUpdateEvent;
      console.log('[ServicesManager] Processing StatusUpdate:', statusEvent.messageId, statusEvent.newStatus);
      // Дополнительная обработка, если нужна
    });

    // Обработчик изменения статуса пользователя
    eventQueueService.registerHandler('UserStatusChanged', (event) => {
      const statusEvent = event as UserStatusChangedEvent;
      console.log('[ServicesManager] Processing UserStatusChanged:', statusEvent.userId, statusEvent.isOnline);
      // Дополнительная обработка, если нужна
    });

    // Обработчик индикатора набора текста
    eventQueueService.registerHandler('TypingIndicator', (event) => {
      const typingEvent = event as TypingIndicatorEvent;
      console.log('[ServicesManager] Processing TypingIndicator:', typingEvent.chatId, typingEvent.isTyping);
      // Дополнительная обработка, если нужна
    });

    console.log('[ServicesManager] EventQueue handlers registered');
  }

  /**
   * Настройка обработчиков ConnectivityService
   */
  private setupConnectivityHandlers(): void {
    connectivityService.onConnectionChange((isConnected) => {
      console.log('[ServicesManager] Connection status changed:', isConnected ? 'ONLINE' : 'OFFLINE');
      
      // Переподключить SignalR при восстановлении соединения
      if (isConnected && !signalRService.isConnected) {
        console.log('[ServicesManager] Attempting to reconnect SignalR...');
        // SignalR автоматически переподключается, но можно добавить дополнительную логику
      }
    });

    console.log('[ServicesManager] Connectivity handlers registered');
  }

  /**
   * Получить экземпляр TypingIndicatorService
   */
  getTypingIndicatorService(): TypingIndicatorService | null {
    return this.typingIndicatorService;
  }

  /**
   * Получить статистику всех сервисов
   */
  getStats(): {
    eventQueue: any;
    typingIndicator: any;
    connectivity: boolean;
    signalR: boolean;
  } {
    return {
      eventQueue: eventQueueService.getStats(),
      typingIndicator: this.typingIndicatorService?.getStats() || null,
      connectivity: connectivityService.getIsConnected(),
      signalR: signalRService.isConnected,
    };
  }

  /**
   * Освободить все ресурсы
   */
  dispose(): void {
    if (this.typingIndicatorService) {
      this.typingIndicatorService.dispose();
      this.typingIndicatorService = null;
    }

    eventQueueService.dispose();
    connectivityService.dispose();
    signalRService.disconnect();

    this.isInitialized = false;
    console.log('[ServicesManager] Services disposed');
  }
}

// Экспортируем синглтон
export const servicesManager = new ServicesManager();

