import { create } from 'zustand';
import { Message, MessageType, MessageStatus } from '../types/chat';
import { messageApi } from '../api/messageApi';
import { signalRService } from '../services/signalRService';
import { notificationService } from '../services/notificationService';
import { useChatStore } from './chatStore';
import { useAuthStore } from './authStore';
import { outboxRepository } from '../repositories/outboxRepository';
import { indexedDBStorage } from '../services/indexedDBStorage';
import { uuidv4 } from '../utils/uuid';

interface MessageState {
  messagesByChatId: Record<string, Message[]>;
  isSending: boolean;
  isLoading: boolean;
  error: string | null;
  
  loadMessages: (chatId: string, forceRefresh?: boolean) => Promise<void>;
  sendTextMessage: (chatId: string, content: string) => Promise<void>;
  sendAudioMessage: (chatId: string, audioBlob: Blob) => Promise<void>;
  sendImageMessage: (chatId: string, imageFile: File) => Promise<void>;
  addMessage: (message: Message) => void;
  updateMessageStatus: (messageId: string, status: number) => void;
  retryMessage: (localId: string) => Promise<void>;
  deleteMessage: (chatId: string, messageId: string) => Promise<void>;
  markAudioAsPlayed: (chatId: string, messageId: string) => Promise<void>;
  clearError: () => void;
}

export const useMessageStore = create<MessageState>((set) => ({
  messagesByChatId: {},
  isSending: false,
  isLoading: false,
  error: null,

  loadMessages: async (chatId: string, forceRefresh = false) => {
    set({ isLoading: true, error: null });
    
    const authState = useAuthStore.getState();
    const currentUser = authState.user;
    
    if (!currentUser) {
      console.warn('[MessageStore] No current user');
      set({ isLoading: false });
      return;
    }
    
    try {
      // STEP 1: Load from cache first (instant display) if not forcing refresh
      if (!forceRefresh) {
        const cachedMessages = await indexedDBStorage.getCachedMessages(chatId);
        
        // Also load pending messages
        const pendingMessages = await outboxRepository.getPendingMessagesForChat(chatId);
        const localMessages = pendingMessages.map((pm) =>
          outboxRepository.toMessage(pm, currentUser.id, currentUser.displayName)
        );
        
        if (cachedMessages && cachedMessages.length > 0) {
          // Merge cached and local messages
          const allMessagesMap = new Map<string, Message>();
          cachedMessages.forEach((msg) => allMessagesMap.set(msg.id, msg));
          localMessages.forEach((msg) => {
            if (!allMessagesMap.has(msg.id)) {
              allMessagesMap.set(msg.id, msg);
            }
          });
          
          const messages = Array.from(allMessagesMap.values()).sort(
            (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
          );
          
          console.log(`[MessageStore] Loaded ${messages.length} cached messages (${cachedMessages.length} cached + ${localMessages.length} local)`);
          
          set((state) => ({
            messagesByChatId: {
              ...state.messagesByChatId,
              [chatId]: messages,
            },
            isLoading: false,
          }));
        }
      }
      
      // STEP 2: Fetch from API in background
      const syncedMessages = await messageApi.getMessages(chatId);
      console.log('[MessageStore] Loaded synced messages from API:', syncedMessages.length);
      
      // STEP 3: Load pending messages from outbox
      const pendingMessages = await outboxRepository.getPendingMessagesForChat(chatId);
      const localMessages = pendingMessages.map((pm) =>
        outboxRepository.toMessage(pm, currentUser.id, currentUser.displayName)
      );
      
      // STEP 4: Merge synced and local messages
      const allMessagesMap = new Map<string, Message>();
      
      // Add synced messages first
      syncedMessages.forEach((msg) => {
        allMessagesMap.set(msg.id, msg);
      });
      
      // Add local messages (they won't override synced ones with same ID)
      localMessages.forEach((msg) => {
        if (!allMessagesMap.has(msg.id)) {
          allMessagesMap.set(msg.id, msg);
        }
      });
      
      // Convert to array and sort by date
      const messages = Array.from(allMessagesMap.values()).sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      );
      
      console.log(
        `[MSG_SEND] Loaded ${messages.length} messages (${syncedMessages.length} synced + ${localMessages.length} local)`
      );
      
      // STEP 5: Update state
      set((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: messages,
        },
        isLoading: false,
      }));
      
      // STEP 6: Save to cache
      try {
        await indexedDBStorage.cacheMessages(chatId, syncedMessages);
      } catch (cacheError) {
        console.error('[MessageStore] Failed to cache messages:', cacheError);
      }
      
      // Join chat via SignalR
      if (signalRService.isConnected) {
        await signalRService.joinChat(chatId);
      }
    } catch (error: any) {
      console.error('[MessageStore] Load error:', error);
      set({ error: 'Ошибка загрузки сообщений', isLoading: false });
    }
  },

  sendTextMessage: async (chatId: string, content: string) => {
    console.log('[MSG_SEND] Starting local-first send for text message');
    set({ isSending: true, error: null });
    
    try {
      const authState = useAuthStore.getState();
      const currentUser = authState.user;
      
      if (!currentUser) {
        throw new Error('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      const localId = uuidv4();
      const now = new Date().toISOString();
      
      const localMessage: Message = {
        id: localId, // Temporary local ID
        chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.Text,
        content,
        status: MessageStatus.Sending,
        createdAt: now,
        localId,
        isLocalOnly: true,
      };
      
      // STEP 2: Add to UI immediately (optimistic update)
      set((state) => {
        const chatMessages = state.messagesByChatId[chatId] || [];
        return {
          messagesByChatId: {
            ...state.messagesByChatId,
            [chatId]: [...chatMessages, localMessage].sort(
              (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
            ),
          },
          isSending: false,
        };
      });
      console.log('[MSG_SEND] Message added to UI with local ID:', localId);
      
      // STEP 3: Add to outbox queue for persistence
      await outboxRepository.addToOutbox(chatId, MessageType.Text, content);
      
      // STEP 4: Send to backend asynchronously
      syncMessageToBackend(localId, chatId, MessageType.Text, content);
      
    } catch (error: any) {
      console.error('[MSG_SEND] Failed to create local message:', error);
      const errorMessage = error.response?.data?.message || 'Ошибка отправки сообщения';
      set({ error: errorMessage, isSending: false });
      throw error;
    }
  },

  sendAudioMessage: async (chatId: string, audioBlob: Blob) => {
    console.log('[MSG_SEND] Starting local-first send for audio message');
    set({ isSending: true, error: null });
    
    try {
      const authState = useAuthStore.getState();
      const currentUser = authState.user;
      
      if (!currentUser) {
        throw new Error('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      const localId = uuidv4();
      const now = new Date().toISOString();
      
      const localMessage: Message = {
        id: localId, // Temporary local ID
        chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.Audio,
        status: MessageStatus.Sending,
        createdAt: now,
        localId,
        isLocalOnly: true,
      };
      
      // STEP 2: Add to UI immediately (optimistic update)
      set((state) => {
        const chatMessages = state.messagesByChatId[chatId] || [];
        return {
          messagesByChatId: {
            ...state.messagesByChatId,
            [chatId]: [...chatMessages, localMessage].sort(
              (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
            ),
          },
          isSending: false,
        };
      });
      console.log('[MSG_SEND] Audio message added to UI with local ID:', localId);
      
      // STEP 3: Add to outbox queue
      // Note: We store the blob URL temporarily, but audio upload will happen immediately
      const blobUrl = URL.createObjectURL(audioBlob);
      await outboxRepository.addToOutbox(chatId, MessageType.Audio, undefined, blobUrl);
      
      // STEP 4: Send to backend asynchronously with the blob
      syncAudioMessageToBackend(localId, chatId, audioBlob);
      
    } catch (error: any) {
      console.error('[MSG_SEND] Failed to create local audio message:', error);
      const errorMessage = error.response?.data?.message || 'Ошибка отправки аудио';
      set({ error: errorMessage, isSending: false });
      throw error;
    }
  },

  sendImageMessage: async (chatId: string, imageFile: File) => {
    console.log('[MSG_SEND] Starting local-first send for image message');
    set({ isSending: true, error: null });
    
    try {
      const authState = useAuthStore.getState();
      const currentUser = authState.user;
      
      if (!currentUser) {
        throw new Error('User not authenticated');
      }
      
      // STEP 1: Create message locally with temporary ID
      const localId = uuidv4();
      const now = new Date().toISOString();
      
      // Create local preview URL
      const localImagePath = URL.createObjectURL(imageFile);
      
      const localMessage: Message = {
        id: localId,
        chatId,
        senderId: currentUser.id,
        senderName: currentUser.displayName,
        type: MessageType.Image,
        status: MessageStatus.Sending,
        createdAt: now,
        localId,
        isLocalOnly: true,
        localImagePath,
      };
      
      // STEP 2: Add to UI immediately (optimistic update)
      set((state) => {
        const chatMessages = state.messagesByChatId[chatId] || [];
        return {
          messagesByChatId: {
            ...state.messagesByChatId,
            [chatId]: [...chatMessages, localMessage].sort(
              (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
            ),
          },
          isSending: false,
        };
      });
      console.log('[MSG_SEND] Image message added to UI with local ID:', localId);
      
      // STEP 3: Add to outbox queue
      await outboxRepository.addToOutbox(chatId, MessageType.Image, undefined, localImagePath);
      
      // STEP 4: Send to backend asynchronously
      syncImageMessageToBackend(localId, chatId, imageFile);
      
    } catch (error: any) {
      console.error('[MSG_SEND] Failed to create local image message:', error);
      const errorMessage = error.response?.data?.message || 'Ошибка отправки изображения';
      set({ error: errorMessage, isSending: false });
      throw error;
    }
  },

  addMessage: (message: Message) => {
    console.log('[MSG_RECV] Received message via SignalR:', message.id);
    
    set((state) => {
      const chatMessages = state.messagesByChatId[message.chatId] || [];
      
      // Check if this is a replacement for a local message
      const authState = useAuthStore.getState();
      const currentUserId = authState.user?.id;
      const isFromMe = currentUserId && message.senderId === currentUserId;
      
      // If message is from me, check if we have a local version to replace
      if (isFromMe) {
        const localIndex = chatMessages.findIndex(
          (m) =>
            m.isLocalOnly &&
            m.chatId === message.chatId &&
            m.content === message.content &&
            m.type === message.type &&
            Math.abs(new Date(m.createdAt).getTime() - new Date(message.createdAt).getTime()) < 5000
        );
        
        if (localIndex !== -1) {
          // Replace local message with server message
          const updatedMessages = [...chatMessages];
          const localMessage = updatedMessages[localIndex];
          updatedMessages[localIndex] = {
            ...message,
            localId: localMessage.localId,
            isLocalOnly: false,
          };
          
          console.log('[MSG_RECV] Replaced local message with server message:', message.id);
          
          // Clean up outbox if we have a local ID
          if (localMessage.localId) {
            outboxRepository.markAsSynced(localMessage.localId, message.id);
          }
          
          return {
            messagesByChatId: {
              ...state.messagesByChatId,
              [message.chatId]: updatedMessages,
            },
          };
        }
      }
      
      // Check if message already exists by ID
      const exists = chatMessages.some((m) => m.id === message.id);
      if (exists) {
        console.log('[MSG_RECV] Message already exists, ignoring:', message.id);
        return state;
      }
      
      console.log('[MSG_RECV] Added new message to state:', message.id);
      return {
        messagesByChatId: {
          ...state.messagesByChatId,
          [message.chatId]: [...chatMessages, message].sort(
            (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
          ),
        },
      };
    });
    
    // Update chat's last message and unread count
    const chatStore = useChatStore.getState();
    const chat = chatStore.chats.find((c) => c.id === message.chatId);
    if (chat) {
      chatStore.updateChat({ ...chat, lastMessage: message });
      
      // Increment unread count if message is from someone else and chat is not selected
      const authState = useAuthStore.getState();
      const currentUserId = authState.user?.id;
      const isFromMe = currentUserId && message.senderId === currentUserId;
      const isChatSelected = chatStore.selectedChatId === message.chatId;
      
      if (!isFromMe && !isChatSelected) {
        chatStore.incrementUnreadCount(message.chatId);
        
        // Show browser notification
        const chatTitle = chat.title || 'Новое сообщение';
        let messageBody = message.content || '';
        if (message.type === MessageType.Audio) {
          messageBody = '🎤 Голосовое сообщение';
        } else if (message.type === MessageType.Image) {
          messageBody = '🖼️ Изображение';
        }
        
        notificationService.showMessageNotification(
          chatTitle,
          messageBody,
          message.chatId,
          () => {
            chatStore.selectChat(message.chatId);
          }
        );
      }
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

  retryMessage: async (localId: string) => {
    console.log('[MSG_SEND] Retrying message:', localId);
    
    try {
      const pending = await outboxRepository.getPendingMessageById(localId);
      if (!pending) {
        console.error('[MSG_SEND] Pending message not found:', localId);
        return;
      }
      
      // Mark for retry
      await outboxRepository.retryMessage(localId);
      
      // Update UI to show sending status
      set((state) => {
        const updatedMessagesByChatId = { ...state.messagesByChatId };
        const chatMessages = updatedMessagesByChatId[pending.chatId] || [];
        const messageIndex = chatMessages.findIndex((m) => m.localId === localId);
        
        if (messageIndex !== -1) {
          const updatedMessages = [...chatMessages];
          updatedMessages[messageIndex] = {
            ...updatedMessages[messageIndex],
            status: MessageStatus.Sending,
          };
          updatedMessagesByChatId[pending.chatId] = updatedMessages;
        }
        
        return { messagesByChatId: updatedMessagesByChatId };
      });
      
      // Retry sync
      if (pending.type === MessageType.Text) {
        syncMessageToBackend(localId, pending.chatId, pending.type, pending.content);
      }
      // Note: Audio retry would need special handling with stored blob
    } catch (error) {
      console.error('[MSG_SEND] Failed to retry message:', error);
    }
  },

  deleteMessage: async (chatId: string, messageId: string) => {
    try {
      await messageApi.deleteMessage(messageId);
      
      // Remove message from state
      set((state) => {
        const chatMessages = state.messagesByChatId[chatId] || [];
        return {
          messagesByChatId: {
            ...state.messagesByChatId,
            [chatId]: chatMessages.filter((m) => m.id !== messageId),
          },
        };
      });
      
      console.log('[MessageStore] Message deleted:', messageId);
    } catch (error: any) {
      console.error('[MessageStore] Delete message error:', error);
      throw error;
    }
  },

  markAudioAsPlayed: async (chatId: string, messageId: string) => {
    try {
      await messageApi.markAudioAsPlayed(messageId);
      
      // Update message status in state
      set((state) => {
        const chatMessages = state.messagesByChatId[chatId] || [];
        return {
          messagesByChatId: {
            ...state.messagesByChatId,
            [chatId]: chatMessages.map((m) =>
              m.id === messageId ? { ...m, status: MessageStatus.Played } : m
            ),
          },
        };
      });
      
      console.log('[MessageStore] Audio marked as played:', messageId);
    } catch (error: any) {
      console.error('[MessageStore] Mark audio as played error:', error);
      // Non-fatal, don't throw
    }
  },

  clearError: () => set({ error: null }),
}));

// Helper function to sync text message to backend
async function syncMessageToBackend(
  localId: string,
  chatId: string,
  type: MessageType,
  content?: string
) {
  try {
    console.log('[MSG_SEND] Syncing message to backend:', localId);
    await outboxRepository.markAsSyncing(localId);
    
    // Send via API
    const serverMessage = await messageApi.sendMessage({ chatId, type, content });
    
    console.log('[MSG_SEND] Message synced successfully. Server ID:', serverMessage.id);
    
    // Mark as synced in outbox
    await outboxRepository.markAsSynced(localId, serverMessage.id);
    
    // Update message in UI: replace local ID with server ID
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      updatedMessages[messageIndex] = {
        ...serverMessage,
        localId,
        isLocalOnly: false,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Message updated in UI with server ID:', serverMessage.id);
    }
    
    // Clean up outbox after a delay
    setTimeout(() => {
      outboxRepository.removePendingMessage(localId);
    }, 60000); // 1 minute
  } catch (error: any) {
    console.error('[MSG_SEND] Failed to sync message to backend:', error);
    
    // Mark as failed in outbox
    const errorMessage = error.response?.data?.message || error.message || 'Sync failed';
    await outboxRepository.markAsFailed(localId, errorMessage);
    
    // Update message status to failed in UI
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      updatedMessages[messageIndex] = {
        ...updatedMessages[messageIndex],
        status: MessageStatus.Failed,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Message marked as failed in UI:', localId);
    }
  }
}

// Helper function to sync audio message to backend
async function syncAudioMessageToBackend(localId: string, chatId: string, audioBlob: Blob) {
  try {
    console.log('[MSG_SEND] Syncing audio message to backend:', localId);
    await outboxRepository.markAsSyncing(localId);
    
    // Send via API
    const serverMessage = await messageApi.sendAudioMessage(chatId, audioBlob);
    
    console.log('[MSG_SEND] Audio message synced successfully. Server ID:', serverMessage.id);
    
    // Mark as synced in outbox
    await outboxRepository.markAsSynced(localId, serverMessage.id);
    
    // Update message in UI
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      updatedMessages[messageIndex] = {
        ...serverMessage,
        localId,
        isLocalOnly: false,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Audio message updated in UI with server ID:', serverMessage.id);
    }
    
    // Clean up outbox after a delay
    setTimeout(() => {
      outboxRepository.removePendingMessage(localId);
    }, 60000);
  } catch (error: any) {
    console.error('[MSG_SEND] Failed to sync audio message to backend:', error);
    
    const errorMessage = error.response?.data?.message || error.message || 'Sync failed';
    await outboxRepository.markAsFailed(localId, errorMessage);
    
    // Update UI
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      updatedMessages[messageIndex] = {
        ...updatedMessages[messageIndex],
        status: MessageStatus.Failed,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Audio message marked as failed in UI:', localId);
    }
  }
}

// Helper function to sync image message to backend
async function syncImageMessageToBackend(localId: string, chatId: string, imageFile: File) {
  try {
    console.log('[MSG_SEND] Syncing image message to backend:', localId);
    await outboxRepository.markAsSyncing(localId);
    
    // Send via API
    const serverMessage = await messageApi.sendImageMessage(chatId, imageFile);
    
    console.log('[MSG_SEND] Image message synced successfully. Server ID:', serverMessage.id);
    
    // Mark as synced in outbox
    await outboxRepository.markAsSynced(localId, serverMessage.id);
    
    // Update message in UI
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      // Keep local image path for faster display
      updatedMessages[messageIndex] = {
        ...serverMessage,
        localId,
        isLocalOnly: false,
        localImagePath: updatedMessages[messageIndex].localImagePath,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Image message updated in UI with server ID:', serverMessage.id);
    }
    
    // Clean up outbox after a delay
    setTimeout(() => {
      outboxRepository.removePendingMessage(localId);
    }, 60000);
  } catch (error: any) {
    console.error('[MSG_SEND] Failed to sync image message to backend:', error);
    
    const errorMessage = error.response?.data?.message || error.message || 'Sync failed';
    await outboxRepository.markAsFailed(localId, errorMessage);
    
    // Update UI
    const state = useMessageStore.getState();
    const chatMessages = state.messagesByChatId[chatId] || [];
    const messageIndex = chatMessages.findIndex((m) => m.id === localId);
    
    if (messageIndex !== -1) {
      const updatedMessages = [...chatMessages];
      updatedMessages[messageIndex] = {
        ...updatedMessages[messageIndex],
        status: MessageStatus.Failed,
      };
      
      useMessageStore.setState((state) => ({
        messagesByChatId: {
          ...state.messagesByChatId,
          [chatId]: updatedMessages,
        },
      }));
      
      console.log('[MSG_SEND] Image message marked as failed in UI:', localId);
    }
  }
}

// Set up SignalR listeners
signalRService.onMessage((message) => {
  useMessageStore.getState().addMessage(message);
});

signalRService.onMessageStatus((messageId, status) => {
  useMessageStore.getState().updateMessageStatus(messageId, status);
});
