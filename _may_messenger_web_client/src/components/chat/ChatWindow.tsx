import { useEffect, useRef, useState, useCallback } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { useMessageStore } from '../../stores/messageStore';
import { signalRService } from '../../services/signalRService';
import { notificationService } from '../../services/notificationService';
import { MessageBubble } from '../message/MessageBubble';
import { MessageInput } from '../message/MessageInput';
import { MessageCircle, ChevronDown } from 'lucide-react';
import { ChatType } from '../../types/chat';

export const ChatWindow = () => {
  const { selectedChatId, chats, clearUnreadCount, highlightMessageId } = useChatStore();
  const { messagesByChatId, loadMessages, sendTextMessage, sendAudioMessage, sendImageMessage, isSending } = useMessageStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const messageRefs = useRef<Map<string, HTMLDivElement>>(new Map());
  const [typingUsers, setTypingUsers] = useState<Map<string, string>>(new Map());
  const typingTimeouts = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());
  const [showScrollToBottom, setShowScrollToBottom] = useState(false);
  const [isNearBottom, setIsNearBottom] = useState(true);

  const selectedChat = chats.find((c) => c.id === selectedChatId);
  const messages = selectedChatId ? messagesByChatId[selectedChatId] || [] : [];

  // Scroll to highlighted message when it changes
  useEffect(() => {
    if (highlightMessageId && messages.length > 0) {
      // Wait for messages to render
      setTimeout(() => {
        const messageEl = messageRefs.current.get(highlightMessageId);
        if (messageEl) {
          messageEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }, 100);
    }
  }, [highlightMessageId, messages.length]);

  // Check if scrolled near bottom
  const handleScroll = useCallback(() => {
    const container = messagesContainerRef.current;
    if (!container) return;
    
    const { scrollTop, scrollHeight, clientHeight } = container;
    const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
    const nearBottom = distanceFromBottom < 150;
    
    setIsNearBottom(nearBottom);
    setShowScrollToBottom(distanceFromBottom > 500);
  }, []);

  const scrollToBottom = useCallback((smooth = true) => {
    messagesEndRef.current?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto' });
  }, []);

  useEffect(() => {
    if (selectedChatId) {
      loadMessages(selectedChatId);
      
      // Clear unread count when opening chat
      clearUnreadCount(selectedChatId);
      
      // Set current chat for notification service
      notificationService.setCurrentChat(selectedChatId);
    }

    return () => {
      notificationService.setCurrentChat(null);
    };
  }, [selectedChatId]);

  useEffect(() => {
    // Subscribe to typing indicators
    const unsubscribe = signalRService.onTyping((userId, userName, isTyping) => {
      if (isTyping) {
        setTypingUsers((prev) => {
          const newMap = new Map(prev);
          newMap.set(userId, userName);
          return newMap;
        });

        // Clear existing timeout
        const existingTimeout = typingTimeouts.current.get(userId);
        if (existingTimeout) {
          clearTimeout(existingTimeout);
        }

        // Set new timeout to remove typing indicator after 3 seconds
        const timeout = setTimeout(() => {
          setTypingUsers((prev) => {
            const newMap = new Map(prev);
            newMap.delete(userId);
            return newMap;
          });
          typingTimeouts.current.delete(userId);
        }, 3000);

        typingTimeouts.current.set(userId, timeout);
      } else {
        setTypingUsers((prev) => {
          const newMap = new Map(prev);
          newMap.delete(userId);
          return newMap;
        });

        // Clear timeout
        const existingTimeout = typingTimeouts.current.get(userId);
        if (existingTimeout) {
          clearTimeout(existingTimeout);
          typingTimeouts.current.delete(userId);
        }
      }
    });

    return () => {
      unsubscribe();
      // Clear all timeouts
      typingTimeouts.current.forEach((timeout) => clearTimeout(timeout));
      typingTimeouts.current.clear();
    };
  }, []);

  useEffect(() => {
    // Only auto-scroll to bottom if user is near bottom
    if (isNearBottom) {
      scrollToBottom();
    }
  }, [messages, typingUsers, isNearBottom, scrollToBottom]);

  // Scroll to bottom on initial load
  useEffect(() => {
    if (selectedChatId && messages.length > 0) {
      scrollToBottom(false);
    }
  }, [selectedChatId]);

  if (!selectedChatId) {
    return (
      <div className="h-full flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <MessageCircle className="w-20 h-20 text-gray-400 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-700 mb-2">
            Выберите чат
          </h3>
          <p className="text-gray-500">
            Выберите чат из списка слева, чтобы начать общение
          </p>
        </div>
      </div>
    );
  }

  const handleSendText = async (text: string) => {
    try {
      await sendTextMessage(selectedChatId, text);
      // Send typing stopped indicator
      await signalRService.sendTypingIndicator(selectedChatId, false);
    } catch (error) {
      console.error('Failed to send message', error);
    }
  };

  const handleSendAudio = async (audioBlob: Blob) => {
    try {
      await sendAudioMessage(selectedChatId, audioBlob);
    } catch (error) {
      console.error('Failed to send audio', error);
    }
  };

  const handleSendImage = async (imageFile: File) => {
    try {
      await sendImageMessage(selectedChatId, imageFile);
    } catch (error) {
      console.error('Failed to send image', error);
    }
  };

  const getOnlineStatusText = (chat: typeof selectedChat): string | null => {
    if (!chat || chat.type !== ChatType.Private || !chat.otherParticipantId) {
      return null;
    }
    
    if (chat.otherParticipantIsOnline) {
      return 'онлайн';
    }
    
    if (chat.otherParticipantLastSeenAt) {
      const now = new Date();
      const lastSeen = new Date(chat.otherParticipantLastSeenAt);
      const diffSeconds = Math.floor((now.getTime() - lastSeen.getTime()) / 1000);
      
      if (diffSeconds < 60) return 'только что';
      if (diffSeconds < 3600) return `был(а) ${Math.floor(diffSeconds / 60)} мин назад`;
      if (diffSeconds < 86400) return `был(а) ${Math.floor(diffSeconds / 3600)} ч назад`;
      if (diffSeconds < 604800) return `был(а) ${Math.floor(diffSeconds / 86400)} дн назад`;
      return 'был(а) давно';
    }
    
    return null;
  };

  const onlineStatusText = getOnlineStatusText(selectedChat);

  const typingUserNames = Array.from(typingUsers.values());
  const typingText = typingUserNames.length > 0
    ? typingUserNames.length === 1
      ? `${typingUserNames[0]} печатает...`
      : `${typingUserNames.join(', ')} печатают...`
    : null;

  return (
    <div className="h-full flex flex-col">
      {/* Chat Header */}
      <div className="px-6 py-4 border-b border-gray-200 bg-white">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-indigo-600 rounded-full flex items-center justify-center text-white font-semibold">
            {selectedChat?.title?.[0]?.toUpperCase() || '?'}
          </div>
          <div>
            <h2 className="font-semibold text-gray-900">{selectedChat?.title || 'Загрузка...'}</h2>
            {typingText ? (
              <p className="text-sm text-indigo-600 animate-pulse">{typingText}</p>
            ) : onlineStatusText ? (
              <p className={`text-sm flex items-center gap-1 ${
                onlineStatusText === 'онлайн' ? 'text-green-500' : 'text-gray-500'
              }`}>
                {onlineStatusText === 'онлайн' && (
                  <span className="inline-block w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                )}
                {onlineStatusText}
              </p>
            ) : (
              <p className="text-sm text-gray-500">
                {selectedChat?.participants?.length || 0} участников
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto relative">
        <div 
          ref={messagesContainerRef}
          onScroll={handleScroll}
          className="h-full overflow-y-auto p-4"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23e0e7ff' fill-opacity='0.4'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
            backgroundColor: '#f9fafb',
          }}
        >
          {messages.length === 0 ? (
            <div className="flex items-center justify-center h-full">
              <p className="text-gray-500">Нет сообщений</p>
            </div>
          ) : (
            <>
              {messages.map((message) => (
                <div 
                  key={message.id}
                  ref={(el) => {
                    if (el) messageRefs.current.set(message.id, el);
                  }}
                >
                  <MessageBubble 
                    message={message} 
                    isHighlighted={message.id === highlightMessageId}
                  />
                </div>
              ))}
              {typingText && (
                <div className="flex justify-start mb-4">
                  <div className="bg-gray-200 rounded-2xl px-4 py-3">
                    <div className="flex gap-1">
                      <span className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></span>
                      <span className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></span>
                      <span className="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></span>
                    </div>
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </>
          )}
        </div>
        
        {/* Scroll to bottom FAB */}
        {showScrollToBottom && (
          <button
            onClick={() => scrollToBottom()}
            className="absolute bottom-4 right-4 w-10 h-10 bg-white shadow-lg rounded-full flex items-center justify-center hover:bg-gray-100 transition-all duration-200 border border-gray-200"
            title="Прокрутить вниз"
          >
            <ChevronDown className="w-5 h-5 text-gray-600" />
          </button>
        )}
      </div>

      {/* Message Input */}
      <MessageInput
        onSendText={handleSendText}
        onSendAudio={handleSendAudio}
        onSendImage={handleSendImage}
        disabled={isSending}
      />
    </div>
  );
};
