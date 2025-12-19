// API Types
export interface AuthResponse {
  success: boolean;
  token?: string;
  message?: string;
}

export interface LoginRequest {
  phoneNumber: string;
  password: string;
}

export interface RegisterRequest {
  phoneNumber: string;
  displayName: string;
  password: string;
  inviteCode?: string;
}

// User Types
export interface User {
  id: string;
  phoneNumber: string;
  displayName: string;
  role: UserRole;
  createdAt: string;
}

export enum UserRole {
  User = 0,
  Admin = 1,
}

// Chat Types
export interface Chat {
  id: string;
  type: ChatType;
  title: string;
  avatar?: string;
  lastMessage?: Message;
  unreadCount: number;
  createdAt: string;
  otherParticipantId?: string;
}

export enum ChatType {
  Private = 0,
  Group = 1,
}

export interface CreateChatRequest {
  participantIds: string[];
  title?: string;
}

// Message Types
export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  senderName: string;
  type: MessageType;
  content?: string;
  filePath?: string;
  localAudioPath?: string;
  localImagePath?: string;
  status: MessageStatus;
  createdAt: string;
  localId?: string;
  isLocalOnly?: boolean;
}

export enum MessageType {
  Text = 0,
  Audio = 1,
  Image = 2,
}

export enum MessageStatus {
  Sending = 0,
  Sent = 1,
  Delivered = 2,
  Read = 3,
  Failed = 4,
}

export interface SendMessageRequest {
  chatId: string;
  type: MessageType;
  content?: string;
  clientMessageId?: string;
}

// SignalR Types
export interface SignalRMessage {
  id: string;
  chatId: string;
  senderId: string;
  senderName: string;
  type: number;
  content?: string;
  filePath?: string;
  status: number;
  createdAt: string;
}

// Navigation Types
export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
  Chat: { chatId: string; chatTitle: string };
  NewChat: undefined;
  Settings: undefined;
};

export type MainTabParamList = {
  Chats: undefined;
  Settings: undefined;
};

// Error Types
export interface ApiError {
  message: string;
  code?: string;
  details?: any;
}

