export const API_URL = import.meta.env.VITE_API_URL || 'https://messenger.rare-books.ru';
export const API_BASE = `${API_URL}/api`;
export const HUB_URL = `${API_URL}/hubs/chat`;

export const ENDPOINTS = {
  // Auth
  LOGIN: '/auth/login',
  REGISTER: '/auth/register',
  
  // Users
  USER_PROFILE: '/users/me',
  USERS: '/users',
  CREATE_INVITE: '/users/invite-link',
  MY_INVITES: '/users/my-invite-links',
  
  // Chats
  CHATS: '/chats',
  CHAT_BY_ID: (id: string) => `/chats/${id}`,
  
  // Messages
  MESSAGES: '/messages',
  MESSAGES_BY_CHAT: (chatId: string) => `/messages/${chatId}`,
  SEND_AUDIO: '/messages/audio',
};
