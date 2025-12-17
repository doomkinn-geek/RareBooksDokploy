export interface Chat {
  id: string;
  title: string;
  type: ChatType;
  createdAt: string;
  participants: ChatParticipant[];
  lastMessage?: Message;
}

export interface ChatParticipant {
  userId: string;
  displayName: string;
  joinedAt: string;
}

export enum ChatType {
  Private = 0,
  Group = 1,
}

export interface CreateChatRequest {
  title: string;
  participantIds: string[];
}

export interface Message {
  id: string;
  chatId: string;
  senderId: string;
  senderName: string;
  type: MessageType;
  content?: string;
  filePath?: string;
  status: MessageStatus;
  createdAt: string;
  localId?: string; // Client-side UUID for tracking before server confirms
  isLocalOnly?: boolean; // True if message hasn't been synced to server yet
}

export enum MessageType {
  Text = 0,
  Audio = 1,
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
}
