import { apiClient } from './apiClient';
import { Chat, CreateChatRequest } from '../types/chat';
import { ENDPOINTS } from '../utils/constants';

export const chatApi = {
  async getChats(): Promise<Chat[]> {
    const response = await apiClient.get<Chat[]>(ENDPOINTS.CHATS);
    return response.data;
  },

  async getChatById(chatId: string): Promise<Chat> {
    const response = await apiClient.get<Chat>(ENDPOINTS.CHAT_BY_ID(chatId));
    return response.data;
  },

  async createChat(data: CreateChatRequest): Promise<Chat> {
    const response = await apiClient.post<Chat>(ENDPOINTS.CHATS, data);
    return response.data;
  },

  async createOrGetPrivateChat(targetUserId: string): Promise<Chat> {
    const response = await apiClient.post<Chat>(ENDPOINTS.CREATE_OR_GET_CHAT, { targetUserId });
    return response.data;
  },

  async deleteChat(chatId: string): Promise<void> {
    await apiClient.delete(ENDPOINTS.CHAT_BY_ID(chatId));
  },
};
