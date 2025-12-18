import { Message, MessageType, MessageStatus } from '../../types/chat';
import { useAuthStore } from '../../stores/authStore';
import { useMessageStore } from '../../stores/messageStore';
import { formatTime } from '../../utils/formatters';
import { Check, CheckCheck, Clock, AlertCircle, RotateCw } from 'lucide-react';
import { AudioPlayer } from './AudioPlayer';

interface MessageBubbleProps {
  message: Message;
}

export const MessageBubble = ({ message }: MessageBubbleProps) => {
  const { user } = useAuthStore();
  const { retryMessage } = useMessageStore();
  const isOwnMessage = user?.id === message.senderId;

  const handleRetry = async () => {
    if (message.localId) {
      try {
        await retryMessage(message.localId);
      } catch (error) {
        console.error('[MessageBubble] Failed to retry message:', error);
      }
    }
  };

  const renderStatusIcon = () => {
    if (!isOwnMessage) return null;

    switch (message.status) {
      case MessageStatus.Sending:
        return <Clock className="w-4 h-4 animate-pulse" />;
      case MessageStatus.Sent:
        return <Check className="w-4 h-4" />;
      case MessageStatus.Delivered:
        return <CheckCheck className="w-4 h-4 text-gray-400" />;
      case MessageStatus.Read:
        return <CheckCheck className="w-4 h-4 text-green-400" />;
      case MessageStatus.Failed:
        return <AlertCircle className="w-4 h-4 text-red-400" />;
      default:
        return null;
    }
  };

  return (
    <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'} mb-4`}>
      <div className="flex flex-col items-end gap-1">
        <div
          className={`max-w-[70%] rounded-2xl px-4 py-2 ${
            isOwnMessage
              ? message.status === MessageStatus.Failed
                ? 'bg-red-600 text-white'
                : 'bg-indigo-600 text-white'
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
            {renderStatusIcon()}
          </div>
        </div>
        
        {/* Retry button for failed messages */}
        {isOwnMessage && message.status === MessageStatus.Failed && (
          <button
            onClick={handleRetry}
            className="flex items-center gap-1 px-3 py-1 text-xs text-red-600 bg-red-50 hover:bg-red-100 rounded-full transition-colors"
            title="Повторить отправку"
          >
            <RotateCw className="w-3 h-3" />
            <span>Повторить</span>
          </button>
        )}
      </div>
    </div>
  );
};
