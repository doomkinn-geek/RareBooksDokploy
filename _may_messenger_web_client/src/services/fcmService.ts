/**
 * Firebase Cloud Messaging Service for Web
 * Handles FCM token registration and push notification setup
 * 
 * NOTE: Firebase is optional. To enable:
 * 1. Install: npm install firebase
 * 2. Uncomment the imports below
 * 3. Set your Firebase config
 */

// Uncomment these imports when Firebase is installed:
// import { initializeApp, FirebaseApp } from 'firebase/app';
// import { getMessaging, getToken, onMessage, Messaging, MessagePayload } from 'firebase/messaging';
import { apiClient } from '../api/apiClient';

// Temporary types until Firebase is installed
type FirebaseApp = any;
type Messaging = any;
type MessagePayload = any;

// Firebase configuration - should match your Firebase project
// Uncomment when Firebase is installed:
// const firebaseConfig = {
//   apiKey: "YOUR_API_KEY", // Replace with your actual values
//   authDomain: "YOUR_AUTH_DOMAIN",
//   projectId: "YOUR_PROJECT_ID",
//   storageBucket: "YOUR_STORAGE_BUCKET",
//   messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
//   appId: "YOUR_APP_ID",
// };

// VAPID key for web push
// Uncomment when Firebase is installed:
// const VAPID_KEY = "YOUR_VAPID_KEY"; // Replace with your actual VAPID key

class FCMService {
  private static instance: FCMService;
  // Uncomment when Firebase is installed:
  // private app: FirebaseApp | null = null;
  // private messaging: Messaging | null = null;
  private fcmToken: string | null = null;
  private isInitialized = false;
  // Uncomment when Firebase is installed:
  // private onMessageCallback?: (payload: MessagePayload) => void;

  private constructor() {}

  static getInstance(): FCMService {
    if (!FCMService.instance) {
      FCMService.instance = new FCMService();
    }
    return FCMService.instance;
  }

  /**
   * Check if FCM is supported in this browser
   */
  isSupported(): boolean {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  }

  /**
   * Initialize Firebase and FCM
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      console.log('[FCM] Already initialized');
      return;
    }

    if (!this.isSupported()) {
      console.warn('[FCM] Not supported in this browser');
      return;
    }

    console.warn('[FCM] Firebase not installed. Install with: npm install firebase');
    console.warn('[FCM] Then uncomment Firebase imports in fcmService.ts');
    return;

    // Uncomment when Firebase is installed:
    /*
    try {
      // Check if config is set
      if (firebaseConfig.apiKey === "YOUR_API_KEY") {
        console.warn('[FCM] Firebase config not set. Please update fcmService.ts with your Firebase configuration.');
        return;
      }

      // Initialize Firebase
      this.app = initializeApp(firebaseConfig);
      this.messaging = getMessaging(this.app);

      console.log('[FCM] Firebase initialized');

      // Set up foreground message handler
      if (this.messaging) {
        onMessage(this.messaging, (payload) => {
          console.log('[FCM] Foreground message received:', payload);
          this.onMessageCallback?.(payload);
        });
      }

      this.isInitialized = true;
    } catch (error) {
      console.error('[FCM] Initialization failed:', error);
      throw error;
    }
    */
  }

  /**
   * Request basic browser notification permission (works without Firebase)
   * Returns true if permission granted
   */
  async requestBrowserNotificationPermission(): Promise<boolean> {
    if (!('Notification' in window)) {
      console.warn('[FCM] Notifications not supported');
      return false;
    }

    if (Notification.permission === 'granted') {
      return true;
    }

    if (Notification.permission === 'denied') {
      console.log('[FCM] Notification permission previously denied');
      return false;
    }

    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  /**
   * Show a browser notification (fallback when FCM is not available)
   */
  showLocalNotification(title: string, body: string, chatId?: string): void {
    if (Notification.permission !== 'granted') {
      return;
    }

    const notification = new Notification(title, {
      body,
      icon: '/icon-192.png',
      badge: '/icon-96.png',
      tag: chatId || 'default',
    });

    notification.onclick = () => {
      window.focus();
      if (chatId) {
        // Navigate to chat
        window.location.href = `/web/?chat=${chatId}`;
      }
      notification.close();
    };

    // Auto-close after 5 seconds
    setTimeout(() => notification.close(), 5000);
  }

  /**
   * Request notification permission and get FCM token
   */
  async requestPermissionAndGetToken(): Promise<string | null> {
    console.warn('[FCM] Firebase not installed. Install with: npm install firebase');
    return null;

    // Uncomment when Firebase is installed:
    /*
    if (!this.isInitialized || !this.messaging) {
      console.warn('[FCM] Not initialized');
      return null;
    }

    try {
      // Check if VAPID key is set
      if (VAPID_KEY === "YOUR_VAPID_KEY") {
        console.warn('[FCM] VAPID key not set. Please update fcmService.ts with your VAPID key.');
        return null;
      }

      // Request permission
      const permission = await Notification.requestPermission();
      if (permission !== 'granted') {
        console.log('[FCM] Notification permission denied');
        return null;
      }

      // Get registration
      const registration = await navigator.serviceWorker.ready;

      // Get FCM token
      const token = await getToken(this.messaging, {
        vapidKey: VAPID_KEY,
        serviceWorkerRegistration: registration,
      });

      if (token) {
        console.log('[FCM] Token obtained:', token.substring(0, 20) + '...');
        this.fcmToken = token;
        return token;
      } else {
        console.log('[FCM] No token available');
        return null;
      }
    } catch (error) {
      console.error('[FCM] Failed to get token:', error);
      return null;
    }
    */
  }

  /**
   * Register FCM token with backend
   */
  async registerToken(): Promise<void> {
    if (!this.fcmToken) {
      console.warn('[FCM] No token to register');
      return;
    }

    try {
      const deviceInfo = this.getDeviceInfo();
      
      await apiClient.post('/api/notifications/register-token', {
        token: this.fcmToken,
        deviceInfo,
      });

      console.log('[FCM] Token registered with backend');
    } catch (error) {
      console.error('[FCM] Failed to register token:', error);
      throw error;
    }
  }

  /**
   * Get device information
   */
  private getDeviceInfo(): string {
    const browser = this.getBrowserName();
    const os = this.getOSName();
    
    return `${browser} on ${os}`;
  }

  private getBrowserName(): string {
    const ua = navigator.userAgent;
    if (ua.includes('Firefox')) return 'Firefox';
    if (ua.includes('Edg')) return 'Edge';
    if (ua.includes('Chrome')) return 'Chrome';
    if (ua.includes('Safari')) return 'Safari';
    return 'Unknown Browser';
  }

  private getOSName(): string {
    const ua = navigator.userAgent;
    if (ua.includes('Win')) return 'Windows';
    if (ua.includes('Mac')) return 'macOS';
    if (ua.includes('Linux')) return 'Linux';
    if (ua.includes('Android')) return 'Android';
    if (ua.includes('iOS')) return 'iOS';
    return 'Unknown OS';
  }

  /**
   * Set callback for foreground messages
   */
  setOnMessageCallback(_callback: (payload: MessagePayload) => void): void {
    // Uncomment when Firebase is installed:
    // this.onMessageCallback = callback;
    console.warn('[FCM] Firebase not installed. setOnMessageCallback disabled.');
  }

  /**
   * Get current FCM token
   */
  getToken(): string | null {
    return this.fcmToken;
  }

  /**
   * Deactivate current token
   */
  async deactivateToken(): Promise<void> {
    if (!this.fcmToken) return;

    try {
      await apiClient.post('/api/notifications/deactivate-token', {
        token: this.fcmToken,
      });
      console.log('[FCM] Token deactivated');
      this.fcmToken = null;
    } catch (error) {
      console.error('[FCM] Failed to deactivate token:', error);
    }
  }
}

export const fcmService = FCMService.getInstance();

