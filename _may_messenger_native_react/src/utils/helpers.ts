import { Message, MessageType, MessageStatus } from '../types';

/**
 * Check if message is duplicate
 */
export const isDuplicateMessage = (
  message: Message,
  existingMessages: Message[],
): boolean => {
  return existingMessages.some(m => {
    // 1. Check by server ID (most reliable)
    if (message.id && m.id === message.id) return true;

    // 2. Check by localId (for pending messages)
    if (message.localId && m.localId === message.localId) return true;

    // 3. Check by content+sender+time for text messages
    if (
      m.type === MessageType.Text &&
      message.type === MessageType.Text &&
      m.content === message.content &&
      m.senderId === message.senderId &&
      Math.abs(new Date(m.createdAt).getTime() - new Date(message.createdAt).getTime()) < 1000
    ) {
      return true;
    }

    // 4. Check by filePath for audio/image
    if (
      (m.type === MessageType.Audio || m.type === MessageType.Image) &&
      m.filePath &&
      m.filePath === message.filePath
    ) {
      return true;
    }

    // 5. Check by local path
    if (m.localAudioPath && m.localAudioPath === message.localAudioPath) return true;
    if (m.localImagePath && m.localImagePath === message.localImagePath) return true;

    return false;
  });
};

/**
 * Generate UUID v4
 */
export const generateUUID = (): string => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
};

/**
 * Format date for message display
 */
export const formatMessageDate = (dateString: string): string => {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    // Today: show time
    return date.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
  } else if (diffDays === 1) {
    return 'Вчера';
  } else if (diffDays < 7) {
    return date.toLocaleDateString('ru-RU', { weekday: 'short' });
  } else {
    return date.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
  }
};

/**
 * Format phone number for display
 */
export const formatPhoneNumber = (phone: string): string => {
  // Remove all non-digit characters
  const cleaned = phone.replace(/\D/g, '');
  
  // Format as +X (XXX) XXX-XX-XX
  if (cleaned.length === 11 && cleaned.startsWith('7')) {
    return `+7 (${cleaned.slice(1, 4)}) ${cleaned.slice(4, 7)}-${cleaned.slice(7, 9)}-${cleaned.slice(9)}`;
  }
  
  return phone;
};

/**
 * Truncate text with ellipsis
 */
export const truncateText = (text: string, maxLength: number): string => {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
};

/**
 * Get message preview text
 */
export const getMessagePreview = (message: Message): string => {
  switch (message.type) {
    case MessageType.Text:
      return message.content || '';
    case MessageType.Audio:
      return '🎤 Аудио сообщение';
    case MessageType.Image:
      return '📷 Изображение';
    default:
      return '';
  }
};

/**
 * Debounce function
 */
export const debounce = <T extends (...args: any[]) => any>(
  func: T,
  delay: number,
): ((...args: Parameters<T>) => void) => {
  let timeoutId: any;
  
  return (...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => func(...args), delay);
  };
};

