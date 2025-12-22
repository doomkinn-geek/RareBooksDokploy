/**
 * Event Queue Service - обрабатывает все события приложения последовательно
 * Обеспечивает дедупликацию и упорядоченную обработку событий
 */

// Базовый класс для всех событий
export abstract class AppEvent {
  timestamp: Date;
  eventId: string;

  constructor(timestamp?: Date, eventId?: string) {
    this.timestamp = timestamp || new Date();
    this.eventId = eventId || Date.now().toString() + Math.random().toString(36);
  }

  abstract get type(): string;
}

// Событие получения сообщения через SignalR
export class MessageReceivedEvent extends AppEvent {
  constructor(
    public messageData: any,
    public chatId: string,
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'MessageReceived';
  }
}

// Событие успешной отправки сообщения через REST API
export class MessageSentEvent extends AppEvent {
  constructor(
    public messageId: string,
    public chatId: string,
    public clientMessageId?: string,
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'MessageSent';
  }
}

// Событие обновления статуса сообщения (delivered, read, played)
export class StatusUpdateEvent extends AppEvent {
  constructor(
    public messageId: string,
    public newStatus: number,
    public source: 'SignalR' | 'REST' | 'Local',
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'StatusUpdate';
  }
}

// Событие завершения синхронизации
export class SyncCompleteEvent extends AppEvent {
  constructor(
    public chatId: string,
    public messageCount: number,
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'SyncComplete';
  }
}

// Событие изменения статуса пользователя (online/offline)
export class UserStatusChangedEvent extends AppEvent {
  constructor(
    public userId: string,
    public isOnline: boolean,
    public lastSeenAt: Date,
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'UserStatusChanged';
  }
}

// Событие индикатора набора текста
export class TypingIndicatorEvent extends AppEvent {
  constructor(
    public chatId: string,
    public userId: string,
    public isTyping: boolean,
    timestamp?: Date,
    eventId?: string
  ) {
    super(timestamp, eventId);
  }

  get type(): string {
    return 'TypingIndicator';
  }
}

type EventHandler = (event: AppEvent) => void | Promise<void>;

/**
 * Централизованный сервис очереди событий для последовательной обработки всех событий приложения
 * Обеспечивает дедупликацию и упорядоченную обработку
 */
class EventQueueService {
  private queue: AppEvent[] = [];
  private processedEventIds = new Set<string>();
  private processing = false;

  // Обработчики событий
  private handlers = new Map<string, EventHandler[]>();

  // Статистика
  private totalEventsProcessed = 0;
  private duplicatesSkipped = 0;
  private lastProcessedAt: Date | null = null;

  // Конфигурация
  private static readonly MAX_PROCESSED_EVENT_IDS_SIZE = 1000;
  private static readonly EVENT_TIMEOUT = 30000; // 30 секунд

  constructor() {
    console.log('[EventQueueService] Initialized');
  }

  /**
   * Добавить событие в очередь для обработки
   */
  enqueue(event: AppEvent): void {
    // Проверка на дубликат
    if (this.processedEventIds.has(event.eventId)) {
      this.duplicatesSkipped++;
      console.log(`[EventQueueService] Duplicate event skipped: ${event.type} (${event.eventId})`);
      return;
    }

    this.queue.push(event);
    console.log(`[EventQueueService] Event enqueued: ${event.type} (queue size: ${this.queue.length})`);

    // Запустить обработку, если еще не запущена
    this.processQueue();
  }

  /**
   * Зарегистрировать обработчик для конкретного типа события
   */
  registerHandler(eventType: string, handler: EventHandler): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    this.handlers.get(eventType)!.push(handler);
    console.log(`[EventQueueService] Handler registered for event type: ${eventType}`);
  }

  /**
   * Удалить все обработчики для конкретного типа события
   */
  unregisterHandlers(eventType: string): void {
    this.handlers.delete(eventType);
    console.log(`[EventQueueService] Handlers unregistered for event type: ${eventType}`);
  }

  /**
   * Обработать очередь последовательно
   */
  private async processQueue(): Promise<void> {
    if (this.processing) {
      return; // Уже обрабатывается
    }

    this.processing = true;

    try {
      while (this.queue.length > 0) {
        const event = this.queue.shift()!;

        // Проверка на таймаут события (слишком старое)
        if (Date.now() - event.timestamp.getTime() > EventQueueService.EVENT_TIMEOUT) {
          console.log(`[EventQueueService] Event timeout: ${event.type} (${event.eventId})`);
          continue;
        }

        // Обработать событие
        await this.processEvent(event);

        // Пометить как обработанное
        this.processedEventIds.add(event.eventId);
        this.totalEventsProcessed++;
        this.lastProcessedAt = new Date();

        // Очистка старых обработанных ID событий для предотвращения утечки памяти
        if (this.processedEventIds.size > EventQueueService.MAX_PROCESSED_EVENT_IDS_SIZE) {
          const toRemove = this.processedEventIds.size - EventQueueService.MAX_PROCESSED_EVENT_IDS_SIZE;
          const iterator = this.processedEventIds.values();
          for (let i = 0; i < toRemove; i++) {
            this.processedEventIds.delete(iterator.next().value);
          }
        }
      }
    } catch (error) {
      console.error('[EventQueueService] Error processing queue:', error);
    } finally {
      this.processing = false;
    }
  }

  /**
   * Обработать одно событие
   */
  private async processEvent(event: AppEvent): Promise<void> {
    try {
      console.log(`[EventQueueService] Processing event: ${event.type} (${event.eventId})`);

      const handlers = this.handlers.get(event.type);
      if (!handlers || handlers.length === 0) {
        console.log(`[EventQueueService] No handlers registered for event type: ${event.type}`);
        return;
      }

      // Вызвать все зарегистрированные обработчики
      for (const handler of handlers) {
        try {
          await handler(event);
        } catch (error) {
          console.error(`[EventQueueService] Error in handler for ${event.type}:`, error);
        }
      }

      console.log(`[EventQueueService] Event processed successfully: ${event.type}`);
    } catch (error) {
      console.error(`[EventQueueService] Error processing event: ${event.type}:`, error);
    }
  }

  /**
   * Получить статистику очереди
   */
  getStats(): {
    queueSize: number;
    totalEventsProcessed: number;
    duplicatesSkipped: number;
    lastProcessedAt: string | null;
    isProcessing: boolean;
    processedEventIdsSize: number;
  } {
    return {
      queueSize: this.queue.length,
      totalEventsProcessed: this.totalEventsProcessed,
      duplicatesSkipped: this.duplicatesSkipped,
      lastProcessedAt: this.lastProcessedAt?.toISOString() || null,
      isProcessing: this.processing,
      processedEventIdsSize: this.processedEventIds.size,
    };
  }

  /**
   * Очистить очередь (использовать с осторожностью)
   */
  clear(): void {
    this.queue = [];
    console.log('[EventQueueService] Queue cleared');
  }

  /**
   * Освободить ресурсы
   */
  dispose(): void {
    this.queue = [];
    this.processedEventIds.clear();
    this.handlers.clear();
    console.log('[EventQueueService] Disposed');
  }
}

// Экспортируем синглтон
export const eventQueueService = new EventQueueService();

