import { useEffect } from 'react';
import { useAppDispatch, useAppSelector } from '../store';
import { signalrService } from './signalrService';
import { setConnected, setReconnecting } from '../store/slices/signalrSlice';
import { addMessage, updateMessageStatus } from '../store/slices/messagesSlice';
import { fetchChats } from '../store/slices/chatsSlice';

/**
 * Hook to manage SignalR connection and events
 */
export const useSignalR = () => {
  const dispatch = useAppDispatch();
  const { token, isAuthenticated } = useAppSelector((state) => state.auth);
  const { connected } = useAppSelector((state) => state.signalr);

  useEffect(() => {
    if (!isAuthenticated || !token) {
      return;
    }

    const connectSignalR = async () => {
      try {
        await signalrService.connect(token);
        dispatch(setConnected(true));

        // Setup event listeners
        signalrService.onReceiveMessage((message) => {
          console.log('[SignalR] Message received:', message);
          dispatch(addMessage(message));
        });

        signalrService.onMessageStatusUpdated((messageId, status) => {
          console.log('[SignalR] Status updated:', messageId, status);
          dispatch(updateMessageStatus({ messageId, status }));
        });

        signalrService.onNewChatCreated(() => {
          console.log('[SignalR] New chat created');
          if (token) {
            dispatch(fetchChats(token));
          }
        });

      } catch (error) {
        console.error('[SignalR] Connection error:', error);
        dispatch(setConnected(false));
      }
    };

    connectSignalR();

    return () => {
      signalrService.disconnect();
      dispatch(setConnected(false));
    };
  }, [isAuthenticated, token, dispatch]);

  return { connected };
};

