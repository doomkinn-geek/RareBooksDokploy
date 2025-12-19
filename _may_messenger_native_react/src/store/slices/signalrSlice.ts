import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface SignalRState {
  connected: boolean;
  reconnecting: boolean;
  error: string | null;
}

const initialState: SignalRState = {
  connected: false,
  reconnecting: false,
  error: null,
};

const signalrSlice = createSlice({
  name: 'signalr',
  initialState,
  reducers: {
    setConnected: (state, action: PayloadAction<boolean>) => {
      state.connected = action.payload;
      if (action.payload) {
        state.reconnecting = false;
        state.error = null;
      }
    },
    setReconnecting: (state, action: PayloadAction<boolean>) => {
      state.reconnecting = action.payload;
    },
    setError: (state, action: PayloadAction<string | null>) => {
      state.error = action.payload;
    },
  },
});

export const { setConnected, setReconnecting, setError } = signalrSlice.actions;
export default signalrSlice.reducer;

