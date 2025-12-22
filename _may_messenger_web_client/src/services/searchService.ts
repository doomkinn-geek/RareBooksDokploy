/**
 * Search Service - поиск пользователей и сообщений
 */

import { apiClient } from '../api/apiClient';

export interface User {
  id: string;
  displayName: string;
  phoneNumber: string;
  isOnline?: boolean;
  lastSeenAt?: string;
}

export interface MessageSearchResult {
  messageId: string;
  chatId: string;
  chatTitle: string;
  messageContent: string;
  senderName: string;
  createdAt: string;
}

class SearchService {
  /**
   * Поиск пользователей по запросу
   * @param query - поисковый запрос
   * @param contactsOnly - искать только среди контактов
   */
  async searchUsers(query: string, contactsOnly: boolean = false): Promise<User[]> {
    try {
      const response = await apiClient.get('/api/users/search', {
        params: {
          query,
          contactsOnly,
        },
      });

      if (Array.isArray(response.data)) {
        return response.data as User[];
      }

      return [];
    } catch (error) {
      console.error('[SearchService] Error searching users:', error);
      throw error;
    }
  }

  /**
   * Поиск сообщений по запросу
   * @param query - поисковый запрос
   */
  async searchMessages(query: string): Promise<MessageSearchResult[]> {
    try {
      const response = await apiClient.get('/api/messages/search', {
        params: { query },
      });

      if (Array.isArray(response.data)) {
        return response.data as MessageSearchResult[];
      }

      return [];
    } catch (error) {
      console.error('[SearchService] Error searching messages:', error);
      throw error;
    }
  }

  /**
   * Комбинированный поиск (пользователи + сообщения)
   */
  async searchAll(query: string): Promise<{
    users: User[];
    messages: MessageSearchResult[];
  }> {
    try {
      const [users, messages] = await Promise.all([
        this.searchUsers(query),
        this.searchMessages(query),
      ]);

      return { users, messages };
    } catch (error) {
      console.error('[SearchService] Error in combined search:', error);
      throw error;
    }
  }
}

// Экспортируем синглтон
export const searchService = new SearchService();

