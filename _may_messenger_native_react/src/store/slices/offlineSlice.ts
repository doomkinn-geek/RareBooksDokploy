import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface PendingAction {
  id: string;
  type: 'sendMessage' | 'deleteMessage' | 'markAsRead';
  data: any;
  timestamp: number;
}

interface OfflineState {
  isOnline: boolean;
  pendingActions: PendingAction[];
}

const initialState: OfflineState = {
  isOnline: true,
  pendingActions: [],
};

const offlineSlice = createSlice({
  name: 'offline',
  initialState,
  reducers: {
    setOnlineStatus: (state, action: PayloadAction<boolean>) => {
      state.isOnline = action.payload;
    },
    addPendingAction: (state, action: PayloadAction<PendingAction>) => {
      state.pendingActions.push(action.payload);
    },
    removePendingAction: (state, action: PayloadAction<string>) => {
      state.pendingActions = state.pendingActions.filter(a => a.id !== action.payload);
    },
    clearPendingActions: (state) => {
      state.pendingActions = [];
    },
  },
});

export const { setOnlineStatus, addPendingAction, removePendingAction, clearPendingActions } = offlineSlice.actions;
export default offlineSlice.reducer;

