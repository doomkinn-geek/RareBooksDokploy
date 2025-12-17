import { useState } from 'react';
import { X, Users, MessageCircle, Loader2 } from 'lucide-react';
import { useUsers } from '../../hooks/useUsers';
import { UserSelect } from './UserSelect';
import { useChatStore } from '../../stores/chatStore';
import { useAuthStore } from '../../stores/authStore';

interface CreateChatDialogProps {
  onClose: () => void;
  onChatCreated?: (chatId: string) => void;
}

export const CreateChatDialog = ({ onClose, onChatCreated }: CreateChatDialogProps) => {
  const [activeTab, setActiveTab] = useState<'private' | 'group'>('private');
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([]);
  const [groupName, setGroupName] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { users, isLoading } = useUsers();
  const { createChat, createOrGetPrivateChat } = useChatStore();
  const { user: currentUser } = useAuthStore();

  const handleCreate = async () => {
    setError(null);
    
    if (selectedUserIds.length === 0) {
      setError('Выберите хотя бы одного участника');
      return;
    }

    if (activeTab === 'group' && !groupName.trim()) {
      setError('Введите название группы');
      return;
    }

    setIsCreating(true);
    try {
      let chat;
      
      if (activeTab === 'private') {
        // For private chat, use createOrGetPrivateChat
        chat = await createOrGetPrivateChat(selectedUserIds[0]);
      } else {
        // For group chat, use createChat
        chat = await createChat(groupName.trim(), selectedUserIds);
      }
      
      if (onChatCreated) {
        onChatCreated(chat.id);
      }
      onClose();
    } catch (err: any) {
      console.error('Create chat error:', err);
      setError(err.response?.data?.message || 'Ошибка создания чата');
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full h-[600px] flex flex-col">
        {/* Header */}
        <div className="p-4 border-b flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900">Новый чат</h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-100 transition"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b">
          <button
            onClick={() => {
              setActiveTab('private');
              setSelectedUserIds([]);
              setError(null);
            }}
            className={`flex-1 flex items-center justify-center gap-2 py-3 font-medium transition ${
              activeTab === 'private'
                ? 'text-indigo-600 border-b-2 border-indigo-600'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <MessageCircle className="w-5 h-5" />
            Личный чат
          </button>
          <button
            onClick={() => {
              setActiveTab('group');
              setSelectedUserIds([]);
              setGroupName('');
              setError(null);
            }}
            className={`flex-1 flex items-center justify-center gap-2 py-3 font-medium transition ${
              activeTab === 'group'
                ? 'text-indigo-600 border-b-2 border-indigo-600'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <Users className="w-5 h-5" />
            Групповой чат
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Group name input (only for groups) */}
          {activeTab === 'group' && (
            <div className="p-4 border-b">
              <input
                type="text"
                placeholder="Название группы"
                value={groupName}
                onChange={(e) => setGroupName(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              />
            </div>
          )}

          {/* Selection info */}
          {selectedUserIds.length > 0 && (
            <div className="px-4 py-2 bg-indigo-50 border-b">
              <p className="text-sm text-indigo-700 font-medium">
                {activeTab === 'private' 
                  ? 'Выбран 1 участник' 
                  : `Выбрано участников: ${selectedUserIds.length}`
                }
              </p>
            </div>
          )}

          {/* Error */}
          {error && (
            <div className="px-4 py-2 bg-red-50 border-b">
              <p className="text-sm text-red-700">{error}</p>
            </div>
          )}

          {/* User Select */}
          <div className="flex-1 overflow-hidden">
            {isLoading ? (
              <div className="flex items-center justify-center h-full">
                <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
              </div>
            ) : (
              <UserSelect
                users={users}
                selectedUserIds={selectedUserIds}
                onSelectionChange={setSelectedUserIds}
                multiSelect={activeTab === 'group'}
                currentUserId={currentUser?.id}
              />
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition font-medium"
          >
            Отмена
          </button>
          <button
            onClick={handleCreate}
            disabled={isCreating || selectedUserIds.length === 0}
            className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition font-medium disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {isCreating ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Создание...
              </>
            ) : (
              'Создать'
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

