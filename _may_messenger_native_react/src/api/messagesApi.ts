import { apiClient } from './apiClient';
import { API_ENDPOINTS } from '../utils/constants';
import { Message, SendMessageRequest } from '../types';

export const messagesApi = {
  async getMessages(token: string, chatId: string, skip: number = 0, take: number = 50): Promise<Message[]> {
    apiClient.setToken(token);
    return await apiClient.get<Message[]>(`${API_ENDPOINTS.MESSAGES.GET(chatId)}?skip=${skip}&take=${take}`);
  },

  async sendMessage(token: string, data: SendMessageRequest): Promise<Message> {
    apiClient.setToken(token);
    return await apiClient.post<Message>(API_ENDPOINTS.MESSAGES.SEND, data);
  },

  async sendAudioMessage(token: string, chatId: string, audioFile: any, fileName: string): Promise<Message> {
    apiClient.setToken(token);
    
    const formData = new FormData();
    formData.append('chatId', chatId);
    formData.append('audioFile', audioFile);
    
    return await apiClient.postFormData<Message>(API_ENDPOINTS.MESSAGES.SEND_AUDIO, formData);
  },

  async sendImageMessage(token: string, chatId: string, imageFile: any): Promise<Message> {
    apiClient.setToken(token);
    
    const formData = new FormData();
    formData.append('chatId', chatId);
    formData.append('imageFile', imageFile);
    
    return await apiClient.postFormData<Message>(API_ENDPOINTS.MESSAGES.SEND_IMAGE, formData);
  },

  async markAsRead(token: string, messageIds: string[]): Promise<void> {
    apiClient.setToken(token);
    await apiClient.post(API_ENDPOINTS.MESSAGES.MARK_READ, messageIds);
  },

  async deleteMessage(token: string, messageId: string): Promise<void> {
    apiClient.setToken(token);
    await apiClient.delete(API_ENDPOINTS.MESSAGES.DELETE(messageId));
  },
};

