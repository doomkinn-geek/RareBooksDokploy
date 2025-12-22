/**
 * Typing Indicator Service - управление индикаторами набора текста с debouncing
 * Предотвращает спам на сервер событиями набора текста
 */

type SendTypingIndicator = (chatId: string, isTyping: boolean) => Promise<void>;

class TypingIndicatorService {
  private readonly sendTypingIndicator: SendTypingIndicator;

  // Конфигурация debouncing
  private static readonly TYPING_DEBOUNCE_DELAY = 300; // 300мс
  private static readonly TYPING_STOP_DELAY = 3000; // 3 секунды

  // Отслеживание состояния
  private debounceTimers = new Map<string, number>();
  private stopTimers = new Map<string, number>();
  private currentTypingStates = new Map<string, boolean>();

  constructor(sendTypingIndicator: SendTypingIndicator) {
    this.sendTypingIndicator = sendTypingIndicator;
  }

  /**
   * Пользователь начал набирать текст в чате
   * Debounce событие, чтобы избежать спама
   */
  onTyping(chatId: string): void {
    // Отменить существующий таймер debounce
    const existingTimer = this.debounceTimers.get(chatId);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    // Установить новый таймер debounce
    const timer = window.setTimeout(() => {
      this.setTyping(chatId, true);
    }, TypingIndicatorService.TYPING_DEBOUNCE_DELAY);

    this.debounceTimers.set(chatId, timer);

    // Сбросить таймер автоостановки (пользователь все еще печатает)
    this.resetStopTimer(chatId);
  }

  /**
   * Пользователь перестал набирать текст в чате (явно)
   */
  onStoppedTyping(chatId: string): void {
    this.setTyping(chatId, false);

    const debounceTimer = this.debounceTimers.get(chatId);
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      this.debounceTimers.delete(chatId);
    }

    const stopTimer = this.stopTimers.get(chatId);
    if (stopTimer) {
      clearTimeout(stopTimer);
      this.stopTimers.delete(chatId);
    }
  }

  /**
   * Внутренний метод для установки состояния набора текста
   */
  private setTyping(chatId: string, isTyping: boolean): void {
    // Отправлять только если состояние изменилось
    if (this.currentTypingStates.get(chatId) === isTyping) {
      return;
    }

    this.currentTypingStates.set(chatId, isTyping);

    try {
      this.sendTypingIndicator(chatId, isTyping);
      console.log(`[TypingIndicator] Sent typing=${isTyping} for chat ${chatId}`);
    } catch (error) {
      console.error('[TypingIndicator] Error sending typing indicator:', error);
    }

    // Если начали печатать, установить таймер автоостановки
    if (isTyping) {
      this.resetStopTimer(chatId);
    }
  }

  /**
   * Сбросить таймер автоостановки
   */
  private resetStopTimer(chatId: string): void {
    const existingTimer = this.stopTimers.get(chatId);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    const timer = window.setTimeout(() => {
      this.setTyping(chatId, false);
    }, TypingIndicatorService.TYPING_STOP_DELAY);

    this.stopTimers.set(chatId, timer);
  }

  /**
   * Очистить таймеры для конкретного чата
   */
  cleanupChat(chatId: string): void {
    const debounceTimer = this.debounceTimers.get(chatId);
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      this.debounceTimers.delete(chatId);
    }

    const stopTimer = this.stopTimers.get(chatId);
    if (stopTimer) {
      clearTimeout(stopTimer);
      this.stopTimers.delete(chatId);
    }

    this.currentTypingStates.delete(chatId);
    console.log(`[TypingIndicator] Cleaned up chat ${chatId}`);
  }

  /**
   * Освободить все ресурсы
   */
  dispose(): void {
    this.debounceTimers.forEach((timer) => clearTimeout(timer));
    this.stopTimers.forEach((timer) => clearTimeout(timer));

    this.debounceTimers.clear();
    this.stopTimers.clear();
    this.currentTypingStates.clear();

    console.log('[TypingIndicator] Disposed');
  }

  /**
   * Получить статистику для отладки
   */
  getStats(): {
    activeChats: number;
    typingChats: string[];
  } {
    const typingChats = Array.from(this.currentTypingStates.entries())
      .filter(([, isTyping]) => isTyping)
      .map(([chatId]) => chatId);

    return {
      activeChats: this.currentTypingStates.size,
      typingChats,
    };
  }
}

export default TypingIndicatorService;

