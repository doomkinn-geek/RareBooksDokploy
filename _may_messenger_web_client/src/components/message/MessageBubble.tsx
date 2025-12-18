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
    <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'} mb-4 px-2`}>
      <div className={`flex flex-col gap-1 max-w-[70%] ${isOwnMessage ? 'items-end' : 'items-start'}`}>
        <div
          className={`relative px-4 py-2 shadow-sm break-words ${
            isOwnMessage
              ? message.status === MessageStatus.Failed
                ? 'bg-red-600 text-white rounded-2xl rounded-tr-sm'
                : 'bg-indigo-600 text-white rounded-2xl rounded-tr-sm'
              : 'bg-white text-gray-900 rounded-2xl rounded-tl-sm border border-gray-100'
          }`}
          style={{ minWidth: '4rem' }}
        >
          {!isOwnMessage && (
            <div className="text-xs font-bold text-indigo-600 mb-1">
              {message.senderName || 'Пользователь'}
            </div>
          )}
          
          <div className="text-[15px] leading-relaxed">
            {message.type === MessageType.Text ? (
              <p className="whitespace-pre-wrap">{message.content || ''}</p>
            ) : message.filePath ? (
              <AudioPlayer filePath={message.filePath} isOwnMessage={isOwnMessage} />
            ) : (
              <p className="text-sm opacity-70 italic">Аудио недоступно</p>
            )}
          </div>
          
          <div className={`flex items-center gap-1 justify-end mt-1 text-[10px] select-none ${
            isOwnMessage ? 'text-white/80' : 'text-gray-400'
          }`}>
            <span>{formatTime(message.createdAt)}</span>
            {renderStatusIcon()}
          </div>
        </div>
        
        {/* Retry button for failed messages */}
        {isOwnMessage && message.status === MessageStatus.Failed && (
          <button
            onClick={handleRetry}
            className="flex items-center gap-1 px-3 py-1 text-xs text-red-600 bg-red-50 hover:bg-red-100 rounded-full transition-colors shadow-sm"
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
