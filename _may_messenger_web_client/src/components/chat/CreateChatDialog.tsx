import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
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
  const navigate = useNavigate();

  const handlePrivateChatClick = () => {
    onClose();
    navigate('/new-chat');
  };

  const handleGroupChatClick = () => {
    onClose();
    navigate('/create-group');
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
        {/* Header */}
        <div className="p-4 border-b flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900">Создать чат</h2>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-100 transition"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Options */}
        <div className="p-4 space-y-3">
          <button
            onClick={handlePrivateChatClick}
            className="w-full flex items-center gap-4 p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition text-left"
          >
            <div className="w-12 h-12 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
              <MessageCircle className="w-6 h-6 text-indigo-600" />
            </div>
            <div className="flex-1">
              <h3 className="font-semibold text-gray-900">Личный чат</h3>
              <p className="text-sm text-gray-500">Начать беседу с пользователем</p>
            </div>
          </button>

          <button
            onClick={handleGroupChatClick}
            className="w-full flex items-center gap-4 p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition text-left"
          >
            <div className="w-12 h-12 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
              <Users className="w-6 h-6 text-indigo-600" />
            </div>
            <div className="flex-1">
              <h3 className="font-semibold text-gray-900">Групповой чат</h3>
              <p className="text-sm text-gray-500">Создать группу с несколькими участниками</p>
            </div>
          </button>
        </div>

        {/* Footer */}
        <div className="p-4 border-t">
          <button
            onClick={onClose}
            className="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition font-medium"
          >
            Отмена
          </button>
        </div>
      </div>
    </div>
  );
};

