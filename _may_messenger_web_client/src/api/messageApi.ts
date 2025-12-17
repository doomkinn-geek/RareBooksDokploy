import { apiClient } from './apiClient';
import { Message, SendMessageRequest } from '../types/chat';
import { ENDPOINTS } from '../utils/constants';

export const messageApi = {
  async getMessages(chatId: string, skip = 0, take = 50): Promise<Message[]> {
    const response = await apiClient.get<Message[]>(
      ENDPOINTS.MESSAGES_BY_CHAT(chatId),
      {
        params: { skip, take },
      }
    );
    return response.data;
  },

  async sendMessage(data: SendMessageRequest): Promise<Message> {
    const response = await apiClient.post<Message>(ENDPOINTS.MESSAGES, data);
    return response.data;
  },

  async sendAudioMessage(chatId: string, audioBlob: Blob): Promise<Message> {
    const formData = new FormData();
    formData.append('chatId', chatId);
    formData.append('audioFile', audioBlob, `audio_${Date.now()}.webm`);

    const response = await apiClient.post<Message>(ENDPOINTS.SEND_AUDIO, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  },

  async batchMarkAsRead(messageIds: string[]): Promise<void> {
    await apiClient.post('/api/messages/mark-read', messageIds);
  },

  async getStatusUpdates(chatId: string, since?: Date): Promise<any[]> {
    const params = since ? { since: since.toISOString() } : {};
    const response = await apiClient.get(`/api/messages/${chatId}/status-updates`, { params });
    return response.data;
  },
};
