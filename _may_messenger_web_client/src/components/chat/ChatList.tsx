import { useEffect } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { MessageCircle, Users } from 'lucide-react';
import { formatDate } from '../../utils/formatters';
import { ChatType } from '../../types/chat';

interface ChatListItemProps {
  chat: any;
  isSelected: boolean;
  onClick: () => void;
}

const ChatListItem = ({ chat, isSelected, onClick }: ChatListItemProps) => {
  const lastMessageText = chat.lastMessage?.content || 
    (chat.lastMessage?.type === 1 ? '🎤 Голосовое сообщение' : 'Нет сообщений');
  
  const isGroupChat = chat.type === ChatType.Group;
  
  // Selection style
  const activeClass = isSelected 
    ? 'bg-indigo-50 border-l-4 border-l-indigo-600' 
    : 'border-l-4 border-l-transparent hover:bg-gray-50';

  return (
    <div
      onClick={onClick}
      className={`p-4 cursor-pointer border-b border-gray-100 transition-all duration-200 ${activeClass}`}
    >
      <div className="flex items-start gap-3">
        <div className={`w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg flex-shrink-0 relative shadow-sm ${
          isSelected ? 'bg-indigo-600' : 'bg-gradient-to-br from-indigo-500 to-purple-600'
        }`}>
          {chat.title?.[0]?.toUpperCase() || '?'}
          {isGroupChat && (
            <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-white rounded-full flex items-center justify-center">
               <div className="w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                 <Users className="w-2.5 h-2.5 text-white" />
               </div>
            </div>
          )}
        </div>
        
        <div className="flex-1 min-w-0 pt-0.5">
          <div className="flex items-center justify-between mb-1">
            <h3 className={`font-semibold truncate ${isSelected ? 'text-indigo-900' : 'text-gray-900'}`}>
              {chat.title || 'Без названия'}
            </h3>
            {chat.lastMessage && (
              <span className={`text-xs flex-shrink-0 ml-2 ${isSelected ? 'text-indigo-500 font-medium' : 'text-gray-400'}`}>
                {formatDate(chat.lastMessage.createdAt)}
              </span>
            )}
          </div>
          
          <p className={`text-sm truncate ${isSelected ? 'text-indigo-600/80' : 'text-gray-500'}`}>
            {chat.lastMessage?.senderId && (
              <span className="font-medium mr-1 text-xs opacity-80">
                {chat.lastMessage.senderName ? `${chat.lastMessage.senderName}:` : 'Вы:'}
              </span>
            )}
            {lastMessageText}
          </p>
        </div>
      </div>
    </div>
  );
};

interface ChatListProps {
  filterType?: 'all' | 'private' | 'group';
}

export const ChatList = ({ filterType = 'all' }: ChatListProps) => {
  const { chats, selectedChatId, selectChat, loadChats, isLoading, privateChats, groupChats } = useChatStore();

  useEffect(() => {
    loadChats();
  }, []);

  // Get filtered chats based on filterType
  const displayChats = filterType === 'private' ? privateChats : 
                       filterType === 'group' ? groupChats : 
                       chats;

  if (isLoading && displayChats.length === 0) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Загрузка чатов...</p>
        </div>
      </div>
    );
  }

  if (displayChats.length === 0) {
    const message = filterType === 'private' ? 'Нет личных чатов' :
                    filterType === 'group' ? 'Нет групповых чатов' :
                    'Нет чатов';
    
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center p-8">
          <MessageCircle className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-gray-700 mb-2">
            {message}
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
      {displayChats.map((chat) => (
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
