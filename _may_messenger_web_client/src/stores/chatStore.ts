import { create } from 'zustand';
import { Chat } from '../types/chat';
import { chatApi } from '../api/chatApi';

interface ChatState {
  chats: Chat[];
  selectedChatId: string | null;
  isLoading: boolean;
  error: string | null;
  
  loadChats: () => Promise<void>;
  selectChat: (chatId: string) => void;
  createChat: (title: string, participantIds: string[]) => Promise<Chat>;
  updateChat: (chat: Chat) => void;
  clearError: () => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  chats: [],
  selectedChatId: null,
  isLoading: false,
  error: null,

  loadChats: async () => {
    set({ isLoading: true, error: null });
    try {
      const chats = await chatApi.getChats();
      // Sort by last message time (newest first)
      chats.sort((a, b) => {
        const aTime = a.lastMessage?.createdAt || a.createdAt;
        const bTime = b.lastMessage?.createdAt || b.createdAt;
        return new Date(bTime).getTime() - new Date(aTime).getTime();
      });
      set({ chats, isLoading: false });
    } catch (error: any) {
      set({ error: 'Ошибка загрузки чатов', isLoading: false });
    }
  },

  selectChat: (chatId: string) => {
    set({ selectedChatId: chatId });
  },

  createChat: async (title: string, participantIds: string[]) => {
    set({ error: null });
    try {
      const chat = await chatApi.createChat({ title, participantIds });
      set((state) => ({ chats: [chat, ...state.chats] }));
      return chat;
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Ошибка создания чата';
      set({ error: errorMessage });
      throw error;
    }
  },

  updateChat: (updatedChat: Chat) => {
    set((state) => ({
      chats: state.chats.map((chat) =>
        chat.id === updatedChat.id ? updatedChat : chat
      ),
    }));
  },

  clearError: () => set({ error: null }),
}));
