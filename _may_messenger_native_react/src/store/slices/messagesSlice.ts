import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { Message, MessageType, MessageStatus, SendMessageRequest } from '../../types';
import { messagesApi } from '../../api/messagesApi';
import { isDuplicateMessage, generateUUID } from '../../utils/helpers';

interface MessagesState {
  byChat: { [chatId: string]: Message[] };
  sending: { [localId: string]: Message };
  failed: { [localId: string]: Message };
  loading: { [chatId: string]: boolean };
}

const initialState: MessagesState = {
  byChat: {},
  sending: {},
  failed: {},
  loading: {},
};

// Async Thunks
export const fetchMessages = createAsyncThunk(
  'messages/fetchMessages',
  async ({ token, chatId, skip = 0, take = 50 }: { token: string; chatId: string; skip?: number; take?: number }, { rejectWithValue }) => {
    try {
      const messages = await messagesApi.getMessages(token, chatId, skip, take);
      return { chatId, messages };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const sendTextMessage = createAsyncThunk(
  'messages/sendText',
  async ({ token, chatId, content }: { token: string; chatId: string; content: string }, { rejectWithValue, getState }) => {
    try {
      const localId = generateUUID();
      const clientMessageId = generateUUID();

      const request: SendMessageRequest = {
        chatId,
        type: MessageType.Text,
        content,
        clientMessageId,
      };

      // Return localId for optimistic update
      const response = await messagesApi.sendMessage(token, request);
      return { ...response, localId, clientMessageId };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const sendAudioMessage = createAsyncThunk(
  'messages/sendAudio',
  async ({ token, chatId, audioUri }: { token: string; chatId: string; audioUri: string }, { rejectWithValue }) => {
    try {
      const localId = generateUUID();
      
      // Prepare audio file for upload
      const fileName = `audio_${Date.now()}.m4a`;
      const audioFile = {
        uri: audioUri,
        type: 'audio/m4a',
        name: fileName,
      };

      const response = await messagesApi.sendAudioMessage(token, chatId, audioFile, fileName);
      return { ...response, localId };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const sendImageMessage = createAsyncThunk(
  'messages/sendImage',
  async ({ token, chatId, imageUri, imageType, imageName }: { token: string; chatId: string; imageUri: string; imageType: string; imageName: string }, { rejectWithValue }) => {
    try {
      const localId = generateUUID();
      
      // Prepare image file for upload
      const imageFile = {
        uri: imageUri,
        type: imageType,
        name: imageName,
      };

      const response = await messagesApi.sendImageMessage(token, chatId, imageFile);
      return { ...response, localId };
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

export const markMessagesAsRead = createAsyncThunk(
  'messages/markAsRead',
  async ({ token, messageIds }: { token: string; messageIds: string[] }, { rejectWithValue }) => {
    try {
      await messagesApi.markAsRead(token, messageIds);
      return messageIds;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

// Slice
const messagesSlice = createSlice({
  name: 'messages',
  initialState,
  reducers: {
    addMessage: (state, action: PayloadAction<Message>) => {
      const { chatId } = action.payload;
      
      if (!state.byChat[chatId]) {
        state.byChat[chatId] = [];
      }

      // Check for duplicates
      if (!isDuplicateMessage(action.payload, state.byChat[chatId])) {
        state.byChat[chatId].push(action.payload);
        
        // Sort by createdAt
        state.byChat[chatId].sort((a, b) => 
          new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
        );
      }
    },
    addOptimisticMessage: (state, action: PayloadAction<Message>) => {
      const message = action.payload;
      const { chatId, localId } = message;
      
      if (!state.byChat[chatId]) {
        state.byChat[chatId] = [];
      }

      // Add to messages
      state.byChat[chatId].push(message);
      
      // Add to sending queue
      if (localId) {
        state.sending[localId] = message;
      }
    },
    confirmMessageSent: (state, action: PayloadAction<{ localId: string; serverMessage: Message }>) => {
      const { localId, serverMessage } = action.payload;
      const { chatId } = serverMessage;
      
      // Remove from sending queue
      delete state.sending[localId];
      
      // Update message in chat
      if (state.byChat[chatId]) {
        const index = state.byChat[chatId].findIndex(m => m.localId === localId);
        if (index !== -1) {
          state.byChat[chatId][index] = serverMessage;
        }
      }
    },
    markMessageFailed: (state, action: PayloadAction<string>) => {
      const localId = action.payload;
      const message = state.sending[localId];
      
      if (message) {
        delete state.sending[localId];
        state.failed[localId] = { ...message, status: MessageStatus.Failed };
      }
    },
    updateMessageStatus: (state, action: PayloadAction<{ messageId: string; status: MessageStatus }>) => {
      const { messageId, status } = action.payload;
      
      // Find and update message across all chats
      Object.keys(state.byChat).forEach(chatId => {
        const message = state.byChat[chatId].find(m => m.id === messageId);
        if (message) {
          message.status = status;
        }
      });
    },
    removeMessage: (state, action: PayloadAction<{ chatId: string; messageId: string }>) => {
      const { chatId, messageId } = action.payload;
      
      if (state.byChat[chatId]) {
        state.byChat[chatId] = state.byChat[chatId].filter(m => m.id !== messageId);
      }
    },
  },
  extraReducers: (builder) => {
    // Fetch messages
    builder.addCase(fetchMessages.pending, (state, action) => {
      const chatId = action.meta.arg.chatId;
      state.loading[chatId] = true;
    });
    builder.addCase(fetchMessages.fulfilled, (state, action) => {
      const { chatId, messages } = action.payload;
      state.byChat[chatId] = messages;
      state.loading[chatId] = false;
    });
    builder.addCase(fetchMessages.rejected, (state, action) => {
      const chatId = action.meta.arg.chatId;
      state.loading[chatId] = false;
    });

    // Send message fulfilled
    builder.addCase(sendTextMessage.fulfilled, (state, action) => {
      const { localId } = action.payload;
      if (localId) {
        delete state.sending[localId];
      }
    });

    // Send audio message fulfilled
    builder.addCase(sendAudioMessage.fulfilled, (state, action) => {
      const { localId } = action.payload;
      if (localId) {
        delete state.sending[localId];
      }
    });

    // Send image message fulfilled
    builder.addCase(sendImageMessage.fulfilled, (state, action) => {
      const { localId } = action.payload;
      if (localId) {
        delete state.sending[localId];
      }
    });
  },
});

export const { 
  addMessage, 
  addOptimisticMessage, 
  confirmMessageSent, 
  markMessageFailed,
  updateMessageStatus,
  removeMessage 
} = messagesSlice.actions;

export default messagesSlice.reducer;

