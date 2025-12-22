/**
 * Connectivity Service - мониторинг состояния сетевого подключения
 */

type ConnectionCallback = (isConnected: boolean) => void;

class ConnectivityService {
  private isConnected: boolean = navigator.onLine;
  private callbacks: ConnectionCallback[] = [];
  private checkIntervalId: number | null = null;
  private readonly CHECK_INTERVAL = 30000; // 30 секунд

  constructor() {
    this.init();
  }

  private init(): void {
    // Проверить начальное состояние подключения
    this.isConnected = navigator.onLine;
    console.log(`[Connectivity] Initial status: ${this.isConnected ? 'ONLINE' : 'OFFLINE'}`);

    // Слушать события изменения подключения
    window.addEventListener('online', this.handleOnline);
    window.addEventListener('offline', this.handleOffline);

    // Периодическая проверка (для более надежного обнаружения)
    this.startPeriodicCheck();
  }

  private handleOnline = (): void => {
    const wasConnected = this.isConnected;
    this.isConnected = true;

    if (!wasConnected) {
      console.log('[Connectivity] Status changed: ONLINE');
      this.notifyCallbacks(true);
    }
  };

  private handleOffline = (): void => {
    const wasConnected = this.isConnected;
    this.isConnected = false;

    if (wasConnected) {
      console.log('[Connectivity] Status changed: OFFLINE');
      this.notifyCallbacks(false);
    }
  };

  /**
   * Периодическая проверка подключения
   */
  private startPeriodicCheck(): void {
    this.checkIntervalId = window.setInterval(async () => {
      await this.checkConnectivity();
    }, this.CHECK_INTERVAL);
  }

  /**
   * Проверить подключение сейчас
   */
  async checkConnectivity(): Promise<boolean> {
    try {
      // Попытка fetch с небольшим таймаутом
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch('/api/health', {
        method: 'HEAD',
        signal: controller.signal,
        cache: 'no-cache',
      });

      clearTimeout(timeoutId);

      const wasConnected = this.isConnected;
      this.isConnected = response.ok;

      if (wasConnected !== this.isConnected) {
        console.log(`[Connectivity] Status changed via check: ${this.isConnected ? 'ONLINE' : 'OFFLINE'}`);
        this.notifyCallbacks(this.isConnected);
      }

      return this.isConnected;
    } catch (error) {
      const wasConnected = this.isConnected;
      this.isConnected = false;

      if (wasConnected) {
        console.log('[Connectivity] Status changed via check: OFFLINE');
        this.notifyCallbacks(false);
      }

      return false;
    }
  }

  /**
   * Получить текущий статус подключения
   */
  getIsConnected(): boolean {
    return this.isConnected;
  }

  /**
   * Подписаться на изменения статуса подключения
   */
  onConnectionChange(callback: ConnectionCallback): () => void {
    this.callbacks.push(callback);

    // Вернуть функцию отписки
    return () => {
      this.callbacks = this.callbacks.filter((cb) => cb !== callback);
    };
  }

  /**
   * Уведомить все коллбеки об изменении подключения
   */
  private notifyCallbacks(isConnected: boolean): void {
    this.callbacks.forEach((callback) => {
      try {
        callback(isConnected);
      } catch (error) {
        console.error('[Connectivity] Error in callback:', error);
      }
    });
  }

  /**
   * Освободить ресурсы
   */
  dispose(): void {
    window.removeEventListener('online', this.handleOnline);
    window.removeEventListener('offline', this.handleOffline);

    if (this.checkIntervalId !== null) {
      clearInterval(this.checkIntervalId);
      this.checkIntervalId = null;
    }

    this.callbacks = [];
    console.log('[Connectivity] Disposed');
  }
}

// Экспортируем синглтон
export const connectivityService = new ConnectivityService();

