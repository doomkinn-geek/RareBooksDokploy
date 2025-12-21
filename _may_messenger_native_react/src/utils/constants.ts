// API Configuration
export const API_CONFIG = {
  BASE_URL: 'https://messenger.rare-books.ru',
  API_URL: 'https://messenger.rare-books.ru/api',
  HUB_URL: 'https://messenger.rare-books.ru/hubs/chat',
  TIMEOUT: 30000,
};

// For local development, uncomment:
// export const API_CONFIG = {
//   BASE_URL: 'http://localhost:5279',
//   API_URL: 'http://localhost:5279/api',
//   HUB_URL: 'http://localhost:5279/hubs/chat',
//   TIMEOUT: 30000,
// };

// API Endpoints
export const API_ENDPOINTS = {
  AUTH: {
    REGISTER: '/auth/register',
    LOGIN: '/auth/login',
  },
  CHATS: {
    LIST: '/chats',
    CREATE: '/chats',
    CREATE_OR_GET: '/chats/create-or-get',
    DELETE: (chatId: string) => `/chats/${chatId}`,
  },
  MESSAGES: {
    GET: (chatId: string) => `/messages/${chatId}`,
    SEND: '/messages',
    SEND_AUDIO: '/messages/audio',
    SEND_IMAGE: '/messages/image',
    MARK_READ: '/messages/mark-read',
    DELETE: (messageId: string) => `/messages/${messageId}`,
  },
  NOTIFICATIONS: {
    REGISTER_TOKEN: '/notifications/register-token',
  },
};

// Storage Keys
export const STORAGE_KEYS = {
  AUTH_TOKEN: '@auth_token',
  USER_DATA: '@user_data',
  FCM_TOKEN: '@fcm_token',
};

// App Configuration
export const APP_CONFIG = {
  MESSAGE_PAGE_SIZE: 50,
  RECONNECT_DELAYS: [0, 2000, 5000, 10000, 30000, 60000],
  TYPING_DEBOUNCE_MS: 1000,
  MESSAGE_DEDUP_THRESHOLD_MS: 1000,
};

