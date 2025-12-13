import { Message, MessageType } from '../../types/chat';
import { useAuthStore } from '../../stores/authStore';
import { formatTime } from '../../utils/formatters';
import { Check, CheckCheck } from 'lucide-react';
import { AudioPlayer } from './AudioPlayer';

interface MessageBubbleProps {
  message: Message;
}

export const MessageBubble = ({ message }: MessageBubbleProps) => {
  const { user } = useAuthStore();
  const isOwnMessage = user?.id === message.senderId;

  return (
    <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'} mb-4`}>
      <div
        className={`max-w-[70%] rounded-2xl px-4 py-2 ${
          isOwnMessage
            ? 'bg-indigo-600 text-white'
            : 'bg-gray-200 text-gray-900'
        }`}
      >
        {!isOwnMessage && (
          <div className={`text-xs font-semibold mb-1 ${isOwnMessage ? 'text-white/70' : 'text-indigo-600'}`}>
            {message.senderName || 'Пользователь'}
          </div>
        )}
        
        <div>
          {message.type === MessageType.Text ? (
            <p className="whitespace-pre-wrap break-words">{message.content || ''}</p>
          ) : message.filePath ? (
            <AudioPlayer filePath={message.filePath} isOwnMessage={isOwnMessage} />
          ) : (
            <p className="text-sm opacity-70">Аудио недоступно</p>
          )}
        </div>
        
        <div className={`flex items-center gap-1 justify-end mt-1 text-xs ${
          isOwnMessage ? 'text-white/70' : 'text-gray-500'
        }`}>
          <span>{formatTime(message.createdAt)}</span>
          
          {isOwnMessage && (
            <>
              {message.status >= 3 ? (
                <CheckCheck className="w-4 h-4" />
              ) : (
                <Check className="w-4 h-4" />
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};
