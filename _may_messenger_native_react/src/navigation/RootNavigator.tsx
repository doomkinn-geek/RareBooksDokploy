import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { useAppSelector, useAppDispatch } from '../store';
import { loadStoredAuth } from '../store/slices/authSlice';
import { syncContacts } from '../store/slices/contactsSlice';
import { signalrService } from '../services/signalrService';
import { fcmService } from '../services/fcmService';
import AuthScreen from '../screens/AuthScreen';
import MainNavigator from './MainNavigator';
import ChatScreen from '../screens/ChatScreen';
import NewChatScreen from '../screens/NewChatScreen';
import { RootStackParamList } from '../types';

const Stack = createStackNavigator<RootStackParamList>();

const RootNavigator: React.FC = () => {
  const dispatch = useAppDispatch();
  const { isAuthenticated, loading, token } = useAppSelector((state) => state.auth);
  const contactsSynced = useAppSelector((state) => state.contacts.synced);

  useEffect(() => {
    // Load stored auth on app start
    dispatch(loadStoredAuth());
  }, [dispatch]);

  // Connect to SignalR and sync contacts when authenticated
  useEffect(() => {
    if (isAuthenticated && token) {
      // Connect to SignalR
      signalrService.connect(token).catch((error) => {
        console.error('Failed to connect to SignalR:', error);
      });

      // Sync contacts after login
      if (!contactsSynced) {
        dispatch(syncContacts({ token }));
      }

      // Setup FCM
      const setupFCM = async () => {
        try {
          const hasPermission = await fcmService.requestPermission();
          if (hasPermission) {
            await fcmService.registerToken(token);
          }

          // Setup notification listeners
          fcmService.setupListeners(
            (message) => {
              // Foreground message received
              console.log('Foreground notification:', message);
              // Show local notification or update UI
            },
            (message) => {
              // Notification tapped
              console.log('Notification tapped:', message);
              // Navigate to chat if data contains chatId
              const chatId = message.data?.chatId;
              if (chatId) {
                // You can use navigation here to open the chat
              }
            }
          );
        } catch (error) {
          console.error('[RootNavigator] Failed to setup FCM:', error);
        }
      };

      setupFCM();

      return () => {
        signalrService.disconnect();
      };
    }
  }, [isAuthenticated, token, contactsSynced, dispatch]);

  if (loading) {
    return null; // Show splash screen or loading indicator
  }

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {!isAuthenticated ? (
          <Stack.Screen name="Auth" component={AuthScreen} />
        ) : (
          <>
            <Stack.Screen name="Main" component={MainNavigator} />
            <Stack.Screen 
              name="Chat" 
              component={ChatScreen}
              options={{
                headerShown: true,
              }}
            />
            <Stack.Screen 
              name="NewChat" 
              component={NewChatScreen}
              options={{
                headerShown: true,
                title: 'Новый чат',
              }}
            />
          </>
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default RootNavigator;

