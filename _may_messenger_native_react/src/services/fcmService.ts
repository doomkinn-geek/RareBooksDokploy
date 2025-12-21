import messaging, { FirebaseMessagingTypes } from '@react-native-firebase/messaging';
import { Platform, PermissionsAndroid } from 'react-native';
import { API_CONFIG } from '../utils/constants';

class FCMService {
  private fcmToken: string | null = null;

  /**
   * Request permission to receive notifications
   */
  async requestPermission(): Promise<boolean> {
    try {
      // Check if Firebase is initialized by trying to access the app
      try {
        const app = messaging().app;
        if (!app) {
          console.warn('[FCM] Firebase app is null, skipping notification setup');
          return false;
        }
      } catch (error) {
        console.warn('[FCM] Firebase not initialized, skipping notification setup');
        return false;
      }
      
      if (Platform.OS === 'ios') {
        const authStatus = await messaging().requestPermission();
        const enabled =
          authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
          authStatus === messaging.AuthorizationStatus.PROVISIONAL;
        return enabled;
      } else {
        // Android 13+ requires runtime permission
        if (Platform.Version >= 33) {
          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS
          );
          return granted === PermissionsAndroid.RESULTS.GRANTED;
        }
        return true; // Android < 13 doesn't need runtime permission
      }
    } catch (error) {
      console.error('Failed to request notification permission:', error);
      return false;
    }
  }

  /**
   * Get FCM token
   */
  async getToken(): Promise<string | null> {
    try {
      const token = await messaging().getToken();
      this.fcmToken = token;
      console.log('[FCM] Token:', token);
      return token;
    } catch (error) {
      console.error('[FCM] Failed to get token:', error);
      return null;
    }
  }

  /**
   * Register FCM token with server
   */
  async registerToken(jwtToken: string): Promise<boolean> {
    try {
      const fcmToken = await this.getToken();
      if (!fcmToken) {
        return false;
      }

      const response = await fetch(`${API_CONFIG.API_URL}/notifications/register-token`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${jwtToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token: fcmToken,
          platform: Platform.OS,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to register FCM token');
      }

      console.log('[FCM] Token registered successfully');
      return true;
    } catch (error) {
      console.error('[FCM] Failed to register token:', error);
      return false;
    }
  }

  /**
   * Setup notification listeners
   */
  setupListeners(
    onMessageReceived: (message: FirebaseMessagingTypes.RemoteMessage) => void,
    onNotificationOpened: (message: FirebaseMessagingTypes.RemoteMessage) => void
  ) {
    try {
      // Check if Firebase is initialized
      try {
        messaging().app;
      } catch (error) {
        console.warn('[FCM] Firebase not initialized, skipping listeners setup');
        return () => {}; // Return empty cleanup function
      }

      // Foreground message handler
      const unsubscribeForeground = messaging().onMessage(async (remoteMessage) => {
        console.log('[FCM] Foreground message:', remoteMessage);
        onMessageReceived(remoteMessage);
      });

      // Background/Quit message handler (when notification is tapped)
      messaging().onNotificationOpenedApp((remoteMessage) => {
        console.log('[FCM] Notification opened app:', remoteMessage);
        onNotificationOpened(remoteMessage);
      });

      // Check if app was opened from a quit state by tapping notification
      messaging()
        .getInitialNotification()
        .then((remoteMessage) => {
          if (remoteMessage) {
            console.log('[FCM] Notification opened app from quit state:', remoteMessage);
            onNotificationOpened(remoteMessage);
          }
        });

      // Token refresh listener
      const unsubscribeTokenRefresh = messaging().onTokenRefresh((token) => {
        console.log('[FCM] Token refreshed:', token);
        this.fcmToken = token;
        // You should call registerToken here when you have JWT token available
      });

      return () => {
        unsubscribeForeground();
        unsubscribeTokenRefresh();
      };
    } catch (error) {
      console.error('[FCM] Failed to setup listeners:', error);
      return () => {}; // Return empty cleanup function
    }
  }

  /**
   * Get current FCM token (cached)
   */
  getCurrentToken(): string | null {
    return this.fcmToken;
  }
}

export const fcmService = new FCMService();

// Background message handler (must be set at top level)
// Wrapped in try-catch to handle case when Firebase is not initialized
try {
  messaging().setBackgroundMessageHandler(async (remoteMessage) => {
    console.log('[FCM] Background message:', remoteMessage);
    // Handle background message
  });
} catch (error) {
  console.warn('[FCM] Failed to set background message handler, Firebase may not be initialized');
}

