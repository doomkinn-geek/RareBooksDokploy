import { Message, MessageType, MessageStatus } from '../../types/chat';
import { useAuthStore } from '../../stores/authStore';
import { useMessageStore } from '../../stores/messageStore';
import { formatTime } from '../../utils/formatters';
import { Check, CheckCheck, Clock, AlertCircle, RotateCw, Volume2, Trash2 } from 'lucide-react';
import { AudioPlayer } from './AudioPlayer';
import { useState, useRef, useEffect } from 'react';
import { API_BASE_URL } from '../../utils/constants';

interface MessageBubbleProps {
  message: Message;
  isHighlighted?: boolean;
}

export const MessageBubble = ({ message, isHighlighted: propHighlighted }: MessageBubbleProps) => {
  const { user } = useAuthStore();
  const { retryMessage, deleteMessage, markAudioAsPlayed } = useMessageStore();
  const isOwnMessage = user?.id === message.senderId;
  const [fullScreenImage, setFullScreenImage] = useState<string | null>(null);
  const [showContextMenu, setShowContextMenu] = useState(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const audioPlayedRef = useRef(false);

  const handleRetry = async () => {
    if (message.localId) {
      try {
        await retryMessage(message.localId);
      } catch (error) {
        console.error('[MessageBubble] Failed to retry message:', error);
      }
    }
  };

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    if (isOwnMessage) {
      setShowContextMenu(true);
    }
  };

  const handleDelete = async () => {
    setIsDeleting(true);
    try {
      await deleteMessage(message.chatId, message.id);
      setShowDeleteDialog(false);
    } catch (error) {
      console.error('[MessageBubble] Failed to delete message:', error);
    } finally {
      setIsDeleting(false);
    }
  };

  // Mark audio as played when listening (for incoming audio messages)
  const handleAudioPlay = () => {
    if (!isOwnMessage && message.type === MessageType.Audio && !audioPlayedRef.current) {
      audioPlayedRef.current = true;
      markAudioAsPlayed(message.chatId, message.id);
    }
  };

  const renderStatusIcon = () => {
    if (!isOwnMessage) return null;

    switch (message.status) {
      case MessageStatus.Sending:
        return <Clock className="w-4 h-4 text-white/70 animate-pulse" />;
      case MessageStatus.Sent:
        return <Check className="w-4 h-4 text-white/70" />;
      case MessageStatus.Delivered:
        return <CheckCheck className="w-4 h-4 text-gray-400" />;
      case MessageStatus.Read:
        return <CheckCheck className="w-4 h-4 text-green-400" />;
      case MessageStatus.Played:
        return <Volume2 className="w-4 h-4 text-blue-400" />;
      case MessageStatus.Failed:
        return <AlertCircle className="w-4 h-4 text-red-400" />;
      default:
        return null;
    }
  };

  const renderMessageContent = () => {
    switch (message.type) {
      case MessageType.Text:
        return (
          <p 
            className="whitespace-pre-wrap break-words"
            style={{
              wordWrap: 'break-word',
              overflowWrap: 'anywhere',
              hyphens: 'auto'
            }}
          >
            {message.content || ''}
          </p>
        );
      
      case MessageType.Audio:
        return message.filePath ? (
          <AudioPlayer 
            filePath={message.filePath} 
            isOwnMessage={isOwnMessage} 
            onPlay={handleAudioPlay}
          />
        ) : (
          <p className="text-sm opacity-70">Аудио недоступно</p>
        );
      
      case MessageType.Image:
        const imageUrl = message.localImagePath || 
          (message.filePath ? `${API_BASE_URL}${message.filePath}` : null);
        
        return (
          <div 
            className="w-[200px] h-[200px] rounded-lg overflow-hidden cursor-pointer"
            onClick={() => imageUrl && setFullScreenImage(imageUrl)}
          >
            {imageUrl ? (
              <img
                src={imageUrl}
                alt="Изображение"
                className="w-full h-full object-cover"
                loading="lazy"
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                  e.currentTarget.parentElement!.innerHTML = `
                    <div class="w-full h-full bg-gray-300 flex items-center justify-center">
                      <span class="text-sm text-gray-600">Изображение недоступно</span>
                    </div>
                  `;
                }}
              />
            ) : (
              <div className="w-full h-full bg-gray-300 flex items-center justify-center">
                <span className="text-sm text-gray-600">Изображение недоступно</span>
              </div>
            )}
          </div>
        );
      
      default:
        return null;
    }
  };

  return (
    <>
      <div className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'} mb-4`}>
        <div className={`flex flex-col ${isOwnMessage ? 'items-end' : 'items-start'} gap-1 relative`}>
          <div
            onContextMenu={handleContextMenu}
            className={`rounded-2xl px-4 py-2 transition-all duration-300 ${
              propHighlighted || message.isHighlighted 
                ? 'ring-2 ring-yellow-400 bg-yellow-100 animate-pulse' 
                : ''
            } ${
              isOwnMessage
                ? message.status === MessageStatus.Failed
                  ? 'bg-red-600 text-white'
                  : propHighlighted ? 'bg-indigo-500 text-white' : 'bg-indigo-600 text-white'
                : propHighlighted ? 'bg-yellow-100 text-gray-900' : 'bg-gray-200 text-gray-900'
            }`}
            style={{
              maxWidth: 'min(70%, 500px)',
              minWidth: message.type === MessageType.Image ? '200px' : '80px',
            }}
          >
            {!isOwnMessage && (
              <div className="text-xs font-semibold mb-1 text-indigo-600">
                {message.senderName || 'Пользователь'}
              </div>
            )}
            
            <div>
              {renderMessageContent()}
            </div>
            
            <div className={`flex items-center gap-1 justify-end mt-1 text-xs ${
              isOwnMessage ? 'text-white/70' : 'text-gray-500'
            }`}>
              <span>{formatTime(message.createdAt)}</span>
              {renderStatusIcon()}
            </div>
          </div>
          
          {/* Context menu for own messages */}
          {showContextMenu && (
            <>
              <div 
                className="fixed inset-0 z-40" 
                onClick={() => setShowContextMenu(false)}
              />
              <div className="absolute right-0 top-full mt-1 z-50 bg-white rounded-lg shadow-lg border border-gray-200 py-1 min-w-[140px]">
                <button
                  onClick={() => { setShowContextMenu(false); setShowDeleteDialog(true); }}
                  className="w-full px-3 py-2 text-left text-red-600 hover:bg-red-50 flex items-center gap-2 text-sm"
                >
                  <Trash2 className="w-4 h-4" />
                  Удалить
                </button>
              </div>
            </>
          )}
          
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
      
      {/* Delete confirmation dialog */}
      {showDeleteDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-lg shadow-xl p-6 max-w-sm mx-4">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Удалить сообщение</h3>
            <p className="text-gray-600 mb-4">
              Сообщение будет удалено у всех участников чата
            </p>
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowDeleteDialog(false)}
                className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition"
                disabled={isDeleting}
              >
                Отмена
              </button>
              <button
                onClick={handleDelete}
                className="px-4 py-2 bg-red-600 text-white hover:bg-red-700 rounded-lg transition disabled:opacity-50"
                disabled={isDeleting}
              >
                {isDeleting ? 'Удаление...' : 'Удалить'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Full screen image viewer */}
      {fullScreenImage && (
        <div 
          className="fixed inset-0 bg-black/90 z-50 flex items-center justify-center p-4"
          onClick={() => setFullScreenImage(null)}
        >
          <button
            className="absolute top-4 right-4 text-white text-3xl hover:text-gray-300 transition-colors"
            onClick={() => setFullScreenImage(null)}
          >
            ✕
          </button>
          
          <div className="max-w-[90vw] max-h-[90vh]">
            <img
              src={fullScreenImage}
              alt="Полноразмерное изображение"
              className="max-w-full max-h-full object-contain"
              onClick={(e) => e.stopPropagation()}
            />
            
            {(message.senderName || message.createdAt) && (
              <div className="text-white text-center mt-4">
                {message.senderName && <p className="font-semibold">{message.senderName}</p>}
                {message.createdAt && <p className="text-sm">{formatTime(message.createdAt)}</p>}
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
};
