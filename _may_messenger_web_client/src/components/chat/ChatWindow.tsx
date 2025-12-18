import { useEffect, useRef, useState } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { useMessageStore } from '../../stores/messageStore';
import { signalRService } from '../../services/signalRService';
import { notificationService } from '../../services/notificationService';
import { MessageBubble } from '../message/MessageBubble';
import { MessageInput } from '../message/MessageInput';
import { MessageCircle } from 'lucide-react';

export const ChatWindow = () => {
  const { selectedChatId, chats } = useChatStore();
  const { messagesByChatId, loadMessages, sendTextMessage, sendAudioMessage, isSending } = useMessageStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [typingUsers, setTypingUsers] = useState<Map<string, string>>(new Map());
  const typingTimeouts = useRef<Map<string, NodeJS.Timeout>>(new Map());

  const selectedChat = chats.find((c) => c.id === selectedChatId);
  const messages = selectedChatId ? messagesByChatId[selectedChatId] || [] : [];

  useEffect(() => {
    if (selectedChatId) {
      loadMessages(selectedChatId);
      
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
    // Scroll to bottom when messages change
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, typingUsers]);

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
            ) : (
              <p className="text-sm text-gray-500">
                {selectedChat?.participants?.length || 0} участников
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 bg-gray-50">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <p className="text-gray-500">Нет сообщений</p>
          </div>
        ) : (
          <>
            {messages.map((message) => (
              <MessageBubble key={message.id} message={message} />
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

      {/* Message Input */}
      <MessageInput
        onSendText={handleSendText}
        onSendAudio={handleSendAudio}
        disabled={isSending}
      />
    </div>
  );
};
