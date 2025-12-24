import { create } from 'zustand';
import { Chat, ChatType } from '../types/chat';
import { chatApi } from '../api/chatApi';
import { indexedDBStorage } from '../services/indexedDBStorage';
import { signalRService } from '../services/signalRService';

interface ChatState {
  chats: Chat[];
  selectedChatId: string | null;
  highlightMessageId: string | null;
  isLoading: boolean;
  error: string | null;
  
  loadChats: () => Promise<void>;
  selectChat: (chatId: string) => void;
  selectChatWithMessage: (chatId: string, messageId: string) => void;
  clearHighlight: () => void;
  createChat: (title: string, participantIds: string[]) => Promise<Chat>;
  createOrGetPrivateChat: (targetUserId: string) => Promise<Chat>;
  updateChat: (chat: Chat) => void;
  updateParticipantOnlineStatus: (userId: string, isOnline: boolean, lastSeenAt?: string) => void;
  deleteChat: (chatId: string) => Promise<void>;
  clearError: () => void;
  
  // Unread count management
  clearUnreadCount: (chatId: string) => void;
  incrementUnreadCount: (chatId: string) => void;
  
  // Computed properties
  privateChats: Chat[];
  groupChats: Chat[];
  totalUnreadCount: number;
}

export const useChatStore = create<ChatState>((set, get) => ({
  chats: [],
  selectedChatId: null,
  highlightMessageId: null,
  isLoading: false,
  error: null,

  loadChats: async () => {
    set({ isLoading: true, error: null });
    
    try {
      // STEP 1: Load from cache first (instant display)
      const cachedChats = await indexedDBStorage.getCachedChats();
      if (cachedChats && cachedChats.length > 0) {
        console.log('[ChatStore] Loaded cached chats:', cachedChats.length);
        // Sort by last message time (newest first)
        cachedChats.sort((a, b) => {
          const aTime = a.lastMessage?.createdAt || a.createdAt;
          const bTime = b.lastMessage?.createdAt || b.createdAt;
          return new Date(bTime).getTime() - new Date(aTime).getTime();
        });
        set({ chats: cachedChats, isLoading: false });
      }
      
      // STEP 2: Fetch from API in background
      const chats = await chatApi.getChats();
      console.log('[ChatStore] Loaded chats from API:', chats.length);
      
      // Sort by last message time (newest first)
      chats.sort((a, b) => {
        const aTime = a.lastMessage?.createdAt || a.createdAt;
        const bTime = b.lastMessage?.createdAt || b.createdAt;
        return new Date(bTime).getTime() - new Date(aTime).getTime();
      });
      
      // STEP 3: Update state and cache
      set({ chats, isLoading: false });
      
      // Save to cache
      try {
        await indexedDBStorage.cacheChats(chats);
      } catch (cacheError) {
        console.error('[ChatStore] Failed to cache chats:', cacheError);
      }
    } catch (error: any) {
      console.error('[ChatStore] Load error:', error);
      set({ error: 'Ошибка загрузки чатов', isLoading: false });
    }
  },

  selectChat: (chatId: string) => {
    set({ selectedChatId: chatId, highlightMessageId: null });
  },

  selectChatWithMessage: (chatId: string, messageId: string) => {
    set({ selectedChatId: chatId, highlightMessageId: messageId });
    
    // Clear highlight after 3 seconds
    setTimeout(() => {
      const state = get();
      if (state.highlightMessageId === messageId) {
        set({ highlightMessageId: null });
      }
    }, 3000);
  },

  clearHighlight: () => {
    set({ highlightMessageId: null });
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

  createOrGetPrivateChat: async (targetUserId: string) => {
    set({ error: null });
    try {
      const chat = await chatApi.createOrGetPrivateChat(targetUserId);
      // Check if chat already exists in store
      const existingChat = get().chats.find(c => c.id === chat.id);
      if (!existingChat) {
        set((state) => ({ chats: [chat, ...state.chats] }));
      }
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

  updateParticipantOnlineStatus: (userId: string, isOnline: boolean, lastSeenAt?: string) => {
    set((state) => ({
      chats: state.chats.map((chat) => {
        // Only update private chats where this user is the other participant
        if (chat.type === ChatType.Private && chat.otherParticipantId === userId) {
          return {
            ...chat,
            otherParticipantIsOnline: isOnline,
            otherParticipantLastSeenAt: lastSeenAt,
          };
        }
        return chat;
      }),
    }));
  },

  deleteChat: async (chatId: string) => {
    try {
      await chatApi.deleteChat(chatId);
      set((state) => ({
        chats: state.chats.filter((chat) => chat.id !== chatId),
        selectedChatId: state.selectedChatId === chatId ? null : state.selectedChatId,
      }));
      console.log('[ChatStore] Chat deleted:', chatId);
    } catch (error: any) {
      console.error('[ChatStore] Delete error:', error);
      const errorMessage = error.response?.data?.message || 'Ошибка удаления чата';
      set({ error: errorMessage });
      throw error;
    }
  },

  clearError: () => set({ error: null }),

  // Unread count management
  clearUnreadCount: (chatId: string) => {
    set((state) => ({
      chats: state.chats.map((chat) =>
        chat.id === chatId ? { ...chat, unreadCount: 0 } : chat
      ),
    }));
  },

  incrementUnreadCount: (chatId: string) => {
    set((state) => ({
      chats: state.chats.map((chat) =>
        chat.id === chatId 
          ? { ...chat, unreadCount: (chat.unreadCount || 0) + 1 } 
          : chat
      ),
    }));
  },

  // Computed properties
  get privateChats() {
    return get().chats.filter(chat => chat.type === ChatType.Private);
  },

  get groupChats() {
    return get().chats.filter(chat => chat.type === ChatType.Group);
  },

  get totalUnreadCount() {
    return get().chats.reduce((total, chat) => total + (chat.unreadCount || 0), 0);
  },
}));

// Set up SignalR listener for online status updates
signalRService.onOnlineStatus((userId, isOnline, lastSeenAt) => {
  useChatStore.getState().updateParticipantOnlineStatus(userId, isOnline, lastSeenAt);
});
