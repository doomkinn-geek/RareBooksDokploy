/**
 * Hook для использования TypingIndicatorService в компонентах
 */

import { useCallback } from 'react';
import { servicesManager } from '../services/servicesManager';

export const useTypingIndicator = (chatId: string) => {
  const typingService = servicesManager.getTypingIndicatorService();

  const onTyping = useCallback(() => {
    if (typingService) {
      typingService.onTyping(chatId);
    }
  }, [chatId, typingService]);

  const onStoppedTyping = useCallback(() => {
    if (typingService) {
      typingService.onStoppedTyping(chatId);
    }
  }, [chatId, typingService]);

  const cleanup = useCallback(() => {
    if (typingService) {
      typingService.cleanupChat(chatId);
    }
  }, [chatId, typingService]);

  return {
    onTyping,
    onStoppedTyping,
    cleanup,
  };
};

