import { create } from 'zustand';
import { Message, MessageType } from '../types/chat';
import { messageApi } from '../api/messageApi';
import { signalRService } from '../services/signalRService';
import { useChatStore } from './chatStore';

interface MessageState {
  messagesByChatId: Record<string, Message[]>;
  isSending: boolean;
  isLoading: boolean;
  error: string | null;
  
  loadMessages: (chatId: string) => Promise<void>;
  sendTextMessage: (chatId: string, content: string) => Promise<void>;
  sendAudioMessage: (chatId: string, audioBlob: Blob) => Promise<void>;
  addMessage: (message: Message) => void;
  updateMessageStatus: (messageId: string, status: number) => void;
  clearError: () => void;
}

export const useMessageStore = create<MessageState>((set, get) => ({
  messagesByChatId: {},
  isSending: false,
  isLoading: false,
  error: null,

  loadMessages: async (chatId: string) => {
    set({ isLoading: true, error: null });
    try {
      const messages = await messageApi.getMessages(chatId);
      set((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: messages,
        },
        isLoading: false,
      }));
      
      // Join chat via SignalR
      if (signalRService.isConnected) {
        await signalRService.joinChat(chatId);
      }
    } catch (error: any) {
      set({ error: 'Ошибка загрузки сообщений', isLoading: false });
    }
  },

  sendTextMessage: async (chatId: string, content: string) => {
    set({ isSending: true, error: null });
    try {
      await messageApi.sendMessage({
        chatId,
        type: MessageType.Text,
        content,
      });
      set({ isSending: false });
      
      // Message will come via SignalR
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Ошибка отправки сообщения';
      set({ error: errorMessage, isSending: false });
      throw error;
    }
  },

  sendAudioMessage: async (chatId: string, audioBlob: Blob) => {
    set({ isSending: true, error: null });
    try {
      await messageApi.sendAudioMessage(chatId, audioBlob);
      set({ isSending: false });
      
      // Message will come via SignalR
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Ошибка отправки аудио';
      set({ error: errorMessage, isSending: false });
      throw error;
    }
  },

  addMessage: (message: Message) => {
    set((state) => {
      const chatMessages = state.messagesByChatId[message.chatId] || [];
      
      // Check if message already exists
      const exists = chatMessages.some((m) => m.id === message.id);
      if (exists) return state;
      
      return {
        messagesByChatId: {
          ...state.messagesByChatId,
          [message.chatId]: [...chatMessages, message],
        },
      };
    });
    
    // Update chat's last message
    const chatStore = useChatStore.getState();
    const chat = chatStore.chats.find((c) => c.id === message.chatId);
    if (chat) {
      chatStore.updateChat({ ...chat, lastMessage: message });
    }
  },

  updateMessageStatus: (messageId: string, status: number) => {
    set((state) => {
      const updatedMessagesByChatId = { ...state.messagesByChatId };
      
      for (const chatId in updatedMessagesByChatId) {
        const messages = updatedMessagesByChatId[chatId];
        const messageIndex = messages.findIndex((m) => m.id === messageId);
        
        if (messageIndex !== -1) {
          const updatedMessages = [...messages];
          updatedMessages[messageIndex] = {
            ...updatedMessages[messageIndex],
            status,
          };
          updatedMessagesByChatId[chatId] = updatedMessages;
          break;
        }
      }
      
      return { messagesByChatId: updatedMessagesByChatId };
    });
  },

  clearError: () => set({ error: null }),
}));

// Set up SignalR listeners
signalRService.onMessage((message) => {
  useMessageStore.getState().addMessage(message);
});

signalRService.onMessageStatus((messageId, status) => {
  useMessageStore.getState().updateMessageStatus(messageId, status);
});
