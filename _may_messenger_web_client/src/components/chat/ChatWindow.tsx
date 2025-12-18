import { useEffect, useRef } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { useMessageStore } from '../../stores/messageStore';
import { MessageBubble } from '../message/MessageBubble';
import { MessageInput } from '../message/MessageInput';
import { MessageCircle, MoreVertical, Phone, Video } from 'lucide-react';
import { ChatType } from '../../types/chat';

export const ChatWindow = () => {
  const { selectedChatId, chats } = useChatStore();
  const { messagesByChatId, loadMessages, sendTextMessage, sendAudioMessage, isSending } = useMessageStore();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const selectedChat = chats.find((c) => c.id === selectedChatId);
  const messages = selectedChatId ? messagesByChatId[selectedChatId] || [] : [];

  useEffect(() => {
    if (selectedChatId) {
      loadMessages(selectedChatId);
    }
  }, [selectedChatId]);

  useEffect(() => {
    // Scroll to bottom when messages change
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

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

  return (
    <div className="h-full flex flex-col bg-gray-50/50">
      {/* Chat Header */}
      <div className="px-6 py-3 border-b border-gray-200 bg-white shadow-sm z-10">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full flex items-center justify-center text-white font-semibold text-lg shadow-sm">
              {selectedChat?.title?.[0]?.toUpperCase() || '?'}
            </div>
            <div>
              <h2 className="font-bold text-gray-900 leading-tight">{selectedChat?.title || 'Загрузка...'}</h2>
              <p className="text-sm text-gray-500">
                {selectedChat?.type === ChatType.Group 
                  ? `${selectedChat?.participants?.length || 0} участников`
                  : 'В сети' // TODO: Real presence status
                }
              </p>
            </div>
          </div>
          
          <div className="flex items-center gap-2 text-gray-400">
             <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
               <Phone className="w-5 h-5" />
             </button>
             <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
               <Video className="w-5 h-5" />
             </button>
             <button className="p-2 hover:bg-gray-100 rounded-full transition-colors">
               <MoreVertical className="w-5 h-5" />
             </button>
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 bg-[#f0f2f5]">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <p className="text-gray-500">Нет сообщений</p>
          </div>
        ) : (
          <>
            {messages.map((message) => (
              <MessageBubble key={message.id} message={message} />
            ))}
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
