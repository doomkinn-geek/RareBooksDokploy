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
        <div className="w-[360px] border-r border-gray-200 bg-white flex flex-col shadow-sm z-20">
          {/* Header with title and create button */}
          <div className="p-4 border-b border-gray-100 flex items-center justify-between bg-gray-50/30">
            <h2 className="text-xl font-bold text-gray-800">Чаты</h2>
            <button
              onClick={() => setShowCreateDialog(true)}
              className="w-8 h-8 rounded-full bg-indigo-600 text-white hover:bg-indigo-700 transition flex items-center justify-center shadow-sm"
              title="Новый чат"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>

          {/* Tabs */}
          <div className="flex px-2 pt-2 border-b border-gray-100 bg-white">
            <button
              onClick={() => setActiveTab('all')}
              className={`flex-1 pb-2 px-2 text-sm font-medium transition border-b-2 ${
                activeTab === 'all'
                  ? 'text-indigo-600 border-indigo-600'
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-200'
              }`}
            >
              Все
            </button>
            <button
              onClick={() => setActiveTab('private')}
              className={`flex-1 pb-2 px-2 text-sm font-medium transition border-b-2 flex items-center justify-center gap-1.5 ${
                activeTab === 'private'
                  ? 'text-indigo-600 border-indigo-600'
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-200'
              }`}
            >
              <MessageCircle className="w-4 h-4" />
              Личные
            </button>
            <button
              onClick={() => setActiveTab('group')}
              className={`flex-1 pb-2 px-2 text-sm font-medium transition border-b-2 flex items-center justify-center gap-1.5 ${
                activeTab === 'group'
                  ? 'text-indigo-600 border-indigo-600'
                  : 'text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-200'
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
