/**
 * Contacts Service - работа с контактами пользователя
 * Веб-версия не имеет прямого доступа к контактам телефона,
 * но может работать с контактами, синхронизированными с сервера
 */

import { apiClient } from '../api/apiClient';

export interface RegisteredContact {
  userId: string;
  phoneNumberHash: string;
  displayName: string;
}

class ContactsService {
  /**
   * Нормализует номер телефона перед хешированием
   * Удаляет все символы кроме цифр, заменяет начальную "8" на "+7"
   * Примеры:
   * "+7 (909) 492-41-90" -> "+79094924190"
   * "8 (909) 492-41-90"  -> "+79094924190"
   * "8-909-492-41-90"    -> "+79094924190"
   */
  normalizePhoneNumber(phoneNumber: string): string {
    if (!phoneNumber) {
      return '';
    }

    // Удаляем все символы кроме цифр и +
    let cleaned = phoneNumber.replace(/[^\d+]/g, '');

    // Заменяем начальную 8 на +7 (для российских номеров)
    if (cleaned.startsWith('8') && cleaned.length === 11) {
      cleaned = '+7' + cleaned.substring(1);
    }

    // Если номер начинается с 7 (без +), добавляем +
    if (cleaned.startsWith('7') && cleaned.length === 11 && !cleaned.startsWith('+')) {
      cleaned = '+' + cleaned;
    }

    return cleaned;
  }

  /**
   * Хеширует номер телефона с использованием SHA-256
   */
  async hashPhoneNumber(phoneNumber: string): Promise<string> {
    // Нормализуем номер перед хешированием
    const normalized = this.normalizePhoneNumber(phoneNumber);

    // Используем Web Crypto API для хеширования
    const encoder = new TextEncoder();
    const data = encoder.encode(normalized);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);

    // Конвертируем в hex строку
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');

    return hashHex;
  }

  /**
   * Синхронизация контактов с сервером
   * Примечание: веб-версия не может получить контакты телефона напрямую,
   * но может отправить список контактов, если они доступны
   */
  async syncContacts(contacts: { phoneNumber: string; displayName: string }[]): Promise<RegisteredContact[]> {
    try {
      // Подготавливаем данные контактов
      const contactsData = await Promise.all(
        contacts.map(async (c) => {
          const hash = await this.hashPhoneNumber(c.phoneNumber);
          return {
            phoneNumberHash: hash,
            displayName: c.displayName,
          };
        })
      );

      // Отправляем на бэкенд
      const response = await apiClient.post('/api/contacts/sync', {
        contacts: contactsData,
      });

      return response.data as RegisteredContact[];
    } catch (error) {
      console.error('[ContactsService] Failed to sync contacts:', error);
      throw error;
    }
  }

  /**
   * Получить зарегистрированные контакты из синхронизации
   */
  async getRegisteredContacts(): Promise<RegisteredContact[]> {
    try {
      const response = await apiClient.get('/api/contacts/registered');
      return response.data as RegisteredContact[];
    } catch (error) {
      console.error('[ContactsService] Failed to get registered contacts:', error);
      throw error;
    }
  }

  /**
   * Импорт контактов из файла (опциональная функция для веб)
   * Может принимать CSV или JSON файл с контактами
   */
  async importContactsFromFile(file: File): Promise<{ phoneNumber: string; displayName: string }[]> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = (e) => {
        try {
          const content = e.target?.result as string;

          // Попытка парсинга как JSON
          try {
            const jsonData = JSON.parse(content);
            if (Array.isArray(jsonData)) {
              resolve(jsonData);
              return;
            }
          } catch {
            // Не JSON, попробуем CSV
          }

          // Парсинг CSV
          const lines = content.split('\n');
          const contacts = lines
            .slice(1) // Пропустить заголовок
            .filter((line) => line.trim())
            .map((line) => {
              const [displayName, phoneNumber] = line.split(',').map((s) => s.trim());
              return { displayName, phoneNumber };
            })
            .filter((c) => c.displayName && c.phoneNumber);

          resolve(contacts);
        } catch (error) {
          reject(new Error('Не удалось прочитать файл контактов'));
        }
      };

      reader.onerror = () => reject(new Error('Ошибка чтения файла'));
      reader.readAsText(file);
    });
  }
}

// Экспортируем синглтон
export const contactsService = new ContactsService();

