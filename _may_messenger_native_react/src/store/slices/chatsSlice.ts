import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { Chat, Message } from '../../types';
import { chatsApi } from '../../api/chatsApi';

interface ChatsState {
  list: Chat[];
  activeChat: string | null;
  loading: boolean;
  error: string | null;
}

const initialState: ChatsState = {
  list: [],
  activeChat: null,
  loading: false,
  error: null,
};

// Async Thunks
export const fetchChats = createAsyncThunk(
  'chats/fetchChats',
  async (token: string, { rejectWithValue }) => {
    try {
      const chats = await chatsApi.getChats(token);
      return chats;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const createChat = createAsyncThunk(
  'chats/createChat',
  async ({ token, participantIds, title }: { token: string; participantIds: string[]; title?: string }, { rejectWithValue }) => {
    try {
      const chat = await chatsApi.createChat(token, { participantIds, title });
      return chat;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const deleteChat = createAsyncThunk(
  'chats/deleteChat',
  async ({ token, chatId }: { token: string; chatId: string }, { rejectWithValue }) => {
    try {
      await chatsApi.deleteChat(token, chatId);
      return chatId;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

// Slice
const chatsSlice = createSlice({
  name: 'chats',
  initialState,
  reducers: {
    setActiveChat: (state, action: PayloadAction<string | null>) => {
      state.activeChat = action.payload;
    },
    updateChatLastMessage: (state, action: PayloadAction<{ chatId: string; message: Message }>) => {
      const chat = state.list.find(c => c.id === action.payload.chatId);
      if (chat) {
        chat.lastMessage = action.payload.message;
      }
    },
    clearUnreadCount: (state, action: PayloadAction<string>) => {
      const chat = state.list.find(c => c.id === action.payload);
      if (chat) {
        chat.unreadCount = 0;
      }
    },
    incrementUnreadCount: (state, action: PayloadAction<string>) => {
      const chat = state.list.find(c => c.id === action.payload);
      if (chat) {
        chat.unreadCount += 1;
      }
    },
    addNewChat: (state, action: PayloadAction<Chat>) => {
      // Avoid duplicates
      if (!state.list.find(c => c.id === action.payload.id)) {
        state.list.unshift(action.payload);
      }
    },
  },
  extraReducers: (builder) => {
    // Fetch chats
    builder.addCase(fetchChats.pending, (state) => {
      state.loading = true;
      state.error = null;
    });
    builder.addCase(fetchChats.fulfilled, (state, action) => {
      state.loading = false;
      state.list = action.payload;
    });
    builder.addCase(fetchChats.rejected, (state, action) => {
      state.loading = false;
      state.error = action.payload as string;
    });

    // Create chat
    builder.addCase(createChat.fulfilled, (state, action) => {
      // Add if not exists
      if (!state.list.find(c => c.id === action.payload.id)) {
        state.list.unshift(action.payload);
      }
    });

    // Delete chat
    builder.addCase(deleteChat.fulfilled, (state, action) => {
      state.list = state.list.filter(c => c.id !== action.payload);
      if (state.activeChat === action.payload) {
        state.activeChat = null;
      }
    });
  },
});

export const { setActiveChat, updateChatLastMessage, clearUnreadCount, incrementUnreadCount, addNewChat } = chatsSlice.actions;
export default chatsSlice.reducer;

