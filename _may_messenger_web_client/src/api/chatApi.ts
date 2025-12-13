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
};
