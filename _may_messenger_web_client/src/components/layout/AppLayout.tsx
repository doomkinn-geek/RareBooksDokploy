import { ReactNode, useState } from 'react';
import { Header } from './Header';
import { ChatList } from '../chat/ChatList';
import { ChatWindow } from '../chat/ChatWindow';
import { CreateChatDialog } from '../chat/CreateChatDialog';
import { Plus, MessageCircle, Users } from 'lucide-react';
import { useChatStore } from '../../stores/chatStore';

interface AppLayoutProps {
  children?: ReactNode;
}

export const AppLayout = ({ children }: AppLayoutProps) => {
  const [activeTab, setActiveTab] = useState<'all' | 'private' | 'group'>('all');
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const { selectChat } = useChatStore();

  const handleChatCreated = (chatId: string) => {
    selectChat(chatId);
  };

  return (
    <div className="h-screen flex flex-col">
      <Header />
      
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar with Chat List */}
        <div className="w-80 border-r border-gray-200 bg-white flex flex-col">
          {/* Header with title and create button */}
          <div className="p-4 border-b border-gray-200 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-gray-900">Чаты</h2>
            <button
              onClick={() => setShowCreateDialog(true)}
              className="p-2 rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 transition"
              title="Новый чат"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          {/* Tabs */}
          <div className="flex border-b border-gray-200">
            <button
              onClick={() => setActiveTab('all')}
              className={`flex-1 py-3 px-2 text-sm font-medium transition ${
                activeTab === 'all'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              Все
            </button>
            <button
              onClick={() => setActiveTab('private')}
              className={`flex-1 py-3 px-2 text-sm font-medium transition flex items-center justify-center gap-1 ${
                activeTab === 'private'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <MessageCircle className="w-4 h-4" />
              Личные
            </button>
            <button
              onClick={() => setActiveTab('group')}
              className={`flex-1 py-3 px-2 text-sm font-medium transition flex items-center justify-center gap-1 ${
                activeTab === 'group'
                  ? 'text-indigo-600 border-b-2 border-indigo-600'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <Users className="w-4 h-4" />
              Группы
            </button>
          </div>

          {/* Chat List */}
          <div className="flex-1 overflow-hidden">
            <ChatList filterType={activeTab} />
          </div>
        </div>
        
        {/* Main Content Area */}
        <div className="flex-1">
          {children || <ChatWindow />}
        </div>
      </div>

      {/* Create Chat Dialog */}
      {showCreateDialog && (
        <CreateChatDialog
          onClose={() => setShowCreateDialog(false)}
          onChatCreated={handleChatCreated}
        />
      )}
    </div>
  );
};
