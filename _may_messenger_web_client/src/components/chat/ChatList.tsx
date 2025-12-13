import { useEffect } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { Chat MessageCircle } from 'lucide-react';
import { formatDate } from '../../utils/formatters';

interface ChatListItemProps {
  chat: any;
  isSelected: boolean;
  onClick: () => void;
}

const ChatListItem = ({ chat, isSelected, onClick }: ChatListItemProps) => {
  const lastMessageText = chat.lastMessage?.content || 
    (chat.lastMessage?.type === 1 ? '🎤 Голосовое сообщение' : 'Нет сообщений');
  
  return (
    <div
      onClick={onClick}
      className={`p-4 cursor-pointer border-b border-gray-200 hover:bg-gray-50 transition ${
        isSelected ? 'bg-indigo-50 border-l-4 border-l-indigo-600' : ''
      }`}
    >
      <div className="flex items-start gap-3">
        <div className="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center text-white font-semibold flex-shrink-0">
          {chat.title[0].toUpperCase()}
        </div>
        
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between mb-1">
            <h3 className="font-semibold text-gray-900 truncate">{chat.title}</h3>
            {chat.lastMessage && (
              <span className="text-xs text-gray-500 flex-shrink-0 ml-2">
                {formatDate(chat.lastMessage.createdAt)}
              </span>
            )}
          </div>
          
          <p className="text-sm text-gray-600 truncate">{lastMessageText}</p>
        </div>
      </div>
    </div>
  );
};

export const ChatList = () => {
  const { chats, selectedChatId, selectChat, loadChats, isLoading } = useChatStore();

  useEffect(() => {
    loadChats();
  }, []);

  if (isLoading && chats.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Загрузка чатов...</p>
        </div>
      </div>
    );
  }

  if (chats.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center p-8">
          <MessageCircle className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-700 mb-2">
            Нет чатов
          </h3>
          <p className="text-gray-500">
            Создайте новый чат или дождитесь приглашения
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full overflow-y-auto">
      {chats.map((chat) => (
        <ChatListItem
          key={chat.id}
          chat={chat}
          isSelected={chat.id === selectedChatId}
          onClick={() => selectChat(chat.id)}
        />
      ))}
    </div>
  );
};
