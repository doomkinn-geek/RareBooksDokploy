import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './stores/authStore';
import { useChatStore } from './stores/chatStore';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { ChatPage } from './pages/ChatPage';
import { SettingsPage } from './pages/SettingsPage';
import { notificationService } from './services/notificationService';
import { fcmService } from './services/fcmService';
import { signalRService } from './services/signalRService';

function App() {
  const { token, loadUserProfile } = useAuthStore();
  const { loadChats, selectChat } = useChatStore();

  useEffect(() => {
    // Try to load user profile if token exists
    if (token) {
      loadUserProfile();
    }
  }, []);

  useEffect(() => {
    // Initialize notifications when authenticated
    if (token) {
      initializeNotifications();
    }

    // Listen for Service Worker messages (e.g., notification clicks)
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.addEventListener('message', (event) => {
        if (event.data && event.data.type === 'OPEN_CHAT') {
          const chatId = event.data.chatId;
          if (chatId) {
            console.log('[App] Opening chat from notification:', chatId);
            selectChat(chatId);
            // Navigate to chat page if not already there
            window.location.href = `/web/?chat=${chatId}`;
          }
        }
      });
    }

    // Handle URL query parameters (e.g., ?chat=xxx from notification)
    const params = new URLSearchParams(window.location.search);
    const chatId = params.get('chat');
    if (chatId && token) {
      loadChats().then(() => {
        selectChat(chatId);
      });
    }
  }, [token]);

  const initializeNotifications = async () => {
    try {
      // Request browser notification permission
      const permission = await notificationService.requestPermission();
      
      if (permission === 'granted') {
        console.log('[App] Notification permission granted');
        
        // Initialize FCM if supported
        if (fcmService.isSupported()) {
          try {
            await fcmService.initialize();
            const fcmToken = await fcmService.requestPermissionAndGetToken();
            
            if (fcmToken) {
              await fcmService.registerToken();
              console.log('[App] FCM initialized and token registered');
            }

            // Handle foreground messages
            fcmService.setOnMessageCallback((payload) => {
              console.log('[App] FCM foreground message:', payload);
              
              const title = payload.data?.title || payload.notification?.title || 'New Message';
              const body = payload.data?.body || payload.notification?.body || '';
              const chatId = payload.data?.chatId || '';

              notificationService.showMessageNotification(
                title,
                body,
                chatId,
                () => {
                  if (chatId) {
                    selectChat(chatId);
                  }
                }
              );
            });
          } catch (error) {
            console.error('[App] FCM initialization failed:', error);
          }
        }

        // Setup SignalR message handler for notifications
        const unsubscribe = signalRService.onMessage((message) => {
          // Show notification for new messages
          const currentUserId = localStorage.getItem('userId');
          if (message.senderId !== currentUserId) {
            notificationService.showMessageNotification(
              `Message from ${message.senderName}`,
              message.type === 'text' ? message.content || '' : '🎤 Voice message',
              message.chatId,
              () => {
                selectChat(message.chatId);
              }
            );
          }
        });

        return () => {
          unsubscribe();
        };
      }
    } catch (error) {
      console.error('[App] Notification initialization failed:', error);
    }
  };

  return (
    <BrowserRouter basename="/web">
      <Routes>
        <Route
          path="/login"
          element={token ? <Navigate to="/" replace /> : <LoginPage />}
        />
        <Route
          path="/register"
          element={token ? <Navigate to="/" replace /> : <RegisterPage />}
        />
        <Route
          path="/"
          element={token ? <ChatPage /> : <Navigate to="/login" replace />}
        />
        <Route
          path="/settings"
          element={token ? <SettingsPage /> : <Navigate to="/login" replace />}
        />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
