import { ReactNode } from 'react';
import { Header } from './Header';
import { ChatList } from '../chat/ChatList';
import { ChatWindow } from '../chat/ChatWindow';

interface AppLayoutProps {
  children?: ReactNode;
}

export const AppLayout = ({ children }: AppLayoutProps) => {
  return (
    <div className="h-screen flex flex-col">
      <Header />
      
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar with Chat List */}
        <div className="w-80 border-r border-gray-200 bg-white flex flex-col">
          <div className="p-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Чаты</h2>
          </div>
          <div className="flex-1 overflow-hidden">
            <ChatList />
          </div>
        </div>
        
        {/* Main Content Area */}
        <div className="flex-1">
          {children || <ChatWindow />}
        </div>
      </div>
    </div>
  );
};
