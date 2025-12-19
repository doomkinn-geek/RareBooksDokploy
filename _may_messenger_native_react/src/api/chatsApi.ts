import { apiClient } from './apiClient';
import { API_ENDPOINTS } from '../utils/constants';
import { Chat, CreateChatRequest } from '../types';

export const chatsApi = {
  async getChats(token: string): Promise<Chat[]> {
    apiClient.setToken(token);
    return await apiClient.get<Chat[]>(API_ENDPOINTS.CHATS.LIST);
  },

  async createChat(token: string, data: CreateChatRequest): Promise<Chat> {
    apiClient.setToken(token);
    return await apiClient.post<Chat>(API_ENDPOINTS.CHATS.CREATE, data);
  },

  async createOrGetDirectChat(token: string, targetUserId: string): Promise<Chat> {
    apiClient.setToken(token);
    return await apiClient.post<Chat>(API_ENDPOINTS.CHATS.CREATE_OR_GET, { targetUserId });
  },

  async deleteChat(token: string, chatId: string): Promise<void> {
    apiClient.setToken(token);
    await apiClient.delete(API_ENDPOINTS.CHATS.DELETE(chatId));
  },
};

