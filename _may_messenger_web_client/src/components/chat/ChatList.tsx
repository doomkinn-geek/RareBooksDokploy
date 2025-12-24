import { useEffect, useState } from 'react';
import { useChatStore } from '../../stores/chatStore';
import { MessageCircle, Users, Trash2, X } from 'lucide-react';
import { formatDate } from '../../utils/formatters';
import { ChatType, Chat } from '../../types/chat';

interface ChatListItemProps {
  chat: Chat;
  isSelected: boolean;
  onClick: () => void;
  onDelete: (chatId: string) => void;
}

const ChatListItem = ({ chat, isSelected, onClick, onDelete }: ChatListItemProps) => {
  const [showContextMenu, setShowContextMenu] = useState(false);
  
  const lastMessageText = chat.lastMessage?.content || 
    (chat.lastMessage?.type === 1 ? '🎤 Голосовое сообщение' : 
     chat.lastMessage?.type === 2 ? '🖼️ Изображение' : 
     'Нет сообщений');
  
  const isGroupChat = chat.type === ChatType.Group;
  const isOnline = chat.type === ChatType.Private && chat.otherParticipantIsOnline;
  const unreadCount = chat.unreadCount || 0;
  
  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setShowContextMenu(true);
  };
  
  const handleDelete = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowContextMenu(false);
    onDelete(chat.id);
  };
  
  return (
    <div
      onClick={onClick}
      onContextMenu={handleContextMenu}
      className={`p-4 cursor-pointer border-b border-gray-200 hover:bg-gray-50 transition relative ${
        isSelected ? 'bg-indigo-50 border-l-4 border-l-indigo-600' : ''
      }`}
    >
      {/* Context menu */}
      {showContextMenu && (
        <>
          <div 
            className="fixed inset-0 z-40" 
            onClick={(e) => { e.stopPropagation(); setShowContextMenu(false); }}
          />
          <div className="absolute right-2 top-2 z-50 bg-white rounded-lg shadow-lg border border-gray-200 py-1 min-w-[140px]">
            <button
              onClick={handleDelete}
              className="w-full px-3 py-2 text-left text-red-600 hover:bg-red-50 flex items-center gap-2 text-sm"
            >
              <Trash2 className="w-4 h-4" />
              Удалить чат
            </button>
          </div>
        </>
      )}
      
      <div className="flex items-start gap-3">
        <div className="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center text-white font-semibold flex-shrink-0 relative">
          {chat.title?.[0]?.toUpperCase() || '?'}
          {isGroupChat && (
            <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-green-500 rounded-full flex items-center justify-center border-2 border-white">
              <Users className="w-3 h-3 text-white" />
            </div>
          )}
          {isOnline && !isGroupChat && (
            <span className="absolute bottom-0 right-0 w-3 h-3 bg-green-500 border-2 border-white rounded-full" />
          )}
        </div>
        
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-2 flex-1 min-w-0">
              <h3 className={`font-semibold truncate ${unreadCount > 0 ? 'text-gray-900' : 'text-gray-700'}`}>
                {chat.title || 'Без названия'}
              </h3>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0 ml-2">
              {chat.lastMessage && (
                <span className="text-xs text-gray-500">
                  {formatDate(chat.lastMessage.createdAt)}
                </span>
              )}
              {unreadCount > 0 && (
                <span className="min-w-[20px] h-5 px-1.5 bg-indigo-600 text-white text-xs font-medium rounded-full flex items-center justify-center">
                  {unreadCount > 99 ? '99+' : unreadCount}
                </span>
              )}
            </div>
          </div>
          
          <p className={`text-sm truncate ${unreadCount > 0 ? 'text-gray-800 font-medium' : 'text-gray-600'}`}>
            {lastMessageText}
          </p>
        </div>
      </div>
    </div>
  );
};

// Delete confirmation dialog
interface DeleteDialogProps {
  chatTitle: string;
  onConfirm: () => void;
  onCancel: () => void;
}

const DeleteDialog = ({ chatTitle, onConfirm, onCancel }: DeleteDialogProps) => (
  <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
    <div className="bg-white rounded-lg shadow-xl p-6 max-w-sm mx-4">
      <h3 className="text-lg font-semibold text-gray-900 mb-2">Удалить чат</h3>
      <p className="text-gray-600 mb-4">
        Чат "{chatTitle}" и все сообщения будут удалены у всех участников. Это действие нельзя отменить.
      </p>
      <div className="flex gap-3 justify-end">
        <button
          onClick={onCancel}
          className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition"
        >
          Отмена
        </button>
        <button
          onClick={onConfirm}
          className="px-4 py-2 bg-red-600 text-white hover:bg-red-700 rounded-lg transition"
        >
          Удалить
        </button>
      </div>
    </div>
  </div>
);

interface ChatListProps {
  filterType?: 'all' | 'private' | 'group';
}

export const ChatList = ({ filterType = 'all' }: ChatListProps) => {
  const { chats, selectedChatId, selectChat, loadChats, isLoading, privateChats, groupChats, deleteChat } = useChatStore();
  const [deleteDialogChat, setDeleteDialogChat] = useState<Chat | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);

  useEffect(() => {
    loadChats();
  }, []);

  // Get filtered chats based on filterType
  const displayChats = filterType === 'private' ? privateChats : 
                       filterType === 'group' ? groupChats : 
                       chats;

  const handleDeleteRequest = (chatId: string) => {
    const chat = chats.find(c => c.id === chatId);
    if (chat) {
      setDeleteDialogChat(chat);
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteDialogChat) return;
    
    setIsDeleting(true);
    try {
      await deleteChat(deleteDialogChat.id);
      setDeleteDialogChat(null);
    } catch (error) {
      console.error('Failed to delete chat:', error);
    } finally {
      setIsDeleting(false);
    }
  };

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
    <>
      <div className="h-full overflow-y-auto">
        {displayChats.map((chat) => (
          <ChatListItem
            key={chat.id}
            chat={chat}
            isSelected={chat.id === selectedChatId}
            onClick={() => selectChat(chat.id)}
            onDelete={handleDeleteRequest}
          />
        ))}
      </div>
      
      {/* Delete confirmation dialog */}
      {deleteDialogChat && (
        <DeleteDialog
          chatTitle={deleteDialogChat.title}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setDeleteDialogChat(null)}
        />
      )}
    </>
  );
};
