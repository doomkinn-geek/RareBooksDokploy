import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { contactsService, RegisteredContact } from '../../services/contactsService';
import { API_CONFIG } from '../../utils/constants';

interface ContactsState {
  mapping: { [userId: string]: string }; // userId -> displayName
  loading: boolean;
  synced: boolean;
  lastSyncTime: number | null;
}

const initialState: ContactsState = {
  mapping: {},
  loading: false,
  synced: false,
  lastSyncTime: null,
};

// Sync contacts with server
export const syncContacts = createAsyncThunk(
  'contacts/sync',
  async ({ token }: { token: string }, { rejectWithValue }) => {
    try {
      const endpoint = `${API_CONFIG.API_URL}/contacts/sync`;
      const mapping = await contactsService.syncContactsWithServer(token, endpoint);
      return mapping;
    } catch (error: any) {
      return rejectWithValue(error.message);
    }
  }
);

const contactsSlice = createSlice({
  name: 'contacts',
  initialState,
  reducers: {
    // Update a single contact name
    updateContactName: (state, action: PayloadAction<{ userId: string; displayName: string }>) => {
      state.mapping[action.payload.userId] = action.payload.displayName;
    },
    
    // Clear contacts
    clearContacts: (state) => {
      state.mapping = {};
      state.synced = false;
      state.lastSyncTime = null;
    },
  },
  extraReducers: (builder) => {
    // Sync contacts
    builder.addCase(syncContacts.pending, (state) => {
      state.loading = true;
    });
    
    builder.addCase(syncContacts.fulfilled, (state, action) => {
      state.loading = false;
      state.mapping = action.payload;
      state.synced = true;
      state.lastSyncTime = Date.now();
    });
    
    builder.addCase(syncContacts.rejected, (state) => {
      state.loading = false;
    });
  },
});

export const { updateContactName, clearContacts } = contactsSlice.actions;

// Selectors
export const selectContactName = (userId: string) => (state: { contacts: ContactsState }) => {
  return state.contacts.mapping[userId] || null;
};

export const selectAllContacts = (state: { contacts: ContactsState }) => state.contacts.mapping;
export const selectContactsLoading = (state: { contacts: ContactsState }) => state.contacts.loading;
export const selectContactsSynced = (state: { contacts: ContactsState }) => state.contacts.synced;

export default contactsSlice.reducer;

