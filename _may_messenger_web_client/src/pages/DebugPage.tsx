import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, RefreshCw, Wifi, WifiOff, Database, Bell, Trash2 } from 'lucide-react';
import { signalRService } from '../services/signalRService';
import { indexedDBStorage } from '../services/indexedDBStorage';
import { outboxRepository } from '../repositories/outboxRepository';
import { notificationService } from '../services/notificationService';
import { useAuthStore } from '../stores/authStore';
import { useChatStore } from '../stores/chatStore';
import { useMessageStore } from '../stores/messageStore';

interface DebugInfo {
  signalRConnected: boolean;
  notificationPermission: string;
  cachedChatsCount: number;
  cachedMessagesCount: number;
  pendingMessagesCount: number;
  currentUser: string | null;
  selectedChat: string | null;
  totalChats: number;
  totalMessages: number;
  browserInfo: string;
  timestamp: string;
}

export const DebugPage = () => {
  const navigate = useNavigate();
  const { user, isAdmin } = useAuthStore();
  const { chats, selectedChatId } = useChatStore();
  const { messagesByChatId } = useMessageStore();
  
  const [debugInfo, setDebugInfo] = useState<DebugInfo | null>(null);
  const [logs, setLogs] = useState<string[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // Redirect non-admin users
  useEffect(() => {
    if (!isAdmin) {
      navigate('/');
    }
  }, [isAdmin, navigate]);

  const refreshDebugInfo = async () => {
    setIsRefreshing(true);
    addLog('Обновление диагностической информации...');
    
    try {
      // Get cached data counts
      let cachedChatsCount = 0;
      let cachedMessagesCount = 0;
      let pendingMessagesCount = 0;
      
      try {
        const cachedChats = await indexedDBStorage.getCachedChats();
        cachedChatsCount = cachedChats?.length || 0;
      } catch (e) {
        addLog('Ошибка получения кэшированных чатов: ' + e);
      }
      
      try {
        const pendingMessages = await outboxRepository.getAllPending();
        pendingMessagesCount = pendingMessages?.length || 0;
      } catch (e) {
        addLog('Ошибка получения pending сообщений: ' + e);
      }
      
      // Count total messages in store
      let totalMessages = 0;
      Object.values(messagesByChatId).forEach(messages => {
        totalMessages += messages.length;
      });

      const info: DebugInfo = {
        signalRConnected: signalRService.isConnected,
        notificationPermission: notificationService.getPermissionStatus(),
        cachedChatsCount,
        cachedMessagesCount,
        pendingMessagesCount,
        currentUser: user?.displayName || null,
        selectedChat: selectedChatId,
        totalChats: chats.length,
        totalMessages,
        browserInfo: `${navigator.userAgent.substring(0, 80)}...`,
        timestamp: new Date().toISOString(),
      };
      
      setDebugInfo(info);
      addLog('Диагностическая информация обновлена');
    } catch (error) {
      addLog('Ошибка обновления: ' + error);
    } finally {
      setIsRefreshing(false);
    }
  };

  const addLog = (message: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [`[${timestamp}] ${message}`, ...prev.slice(0, 99)]);
  };

  const clearCache = async () => {
    if (!confirm('Очистить весь локальный кэш? Это действие нельзя отменить.')) {
      return;
    }
    
    try {
      addLog('Очистка кэша...');
      await indexedDBStorage.clearAll();
      await outboxRepository.clearAll();
      addLog('Кэш очищен');
      refreshDebugInfo();
    } catch (error) {
      addLog('Ошибка очистки кэша: ' + error);
    }
  };

  const testNotification = async () => {
    addLog('Тестовое уведомление...');
    const permission = await notificationService.requestPermission();
    addLog('Permission: ' + permission);
    
    if (permission === 'granted') {
      await notificationService.show({
        title: 'Тестовое уведомление',
        body: 'Уведомления работают корректно!',
        tag: 'test-notification',
      });
      addLog('Уведомление отправлено');
    } else {
      addLog('Уведомления не разрешены');
    }
  };

  useEffect(() => {
    refreshDebugInfo();
  }, []);

  if (!isAdmin) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-900 text-gray-100">
      {/* Header */}
      <div className="bg-gray-800 border-b border-gray-700 px-4 py-3">
        <div className="flex items-center gap-4">
          <button
            onClick={() => navigate('/')}
            className="p-2 hover:bg-gray-700 rounded-lg transition"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-lg font-semibold">Диагностика</h1>
          <button
            onClick={refreshDebugInfo}
            disabled={isRefreshing}
            className="ml-auto p-2 hover:bg-gray-700 rounded-lg transition disabled:opacity-50"
          >
            <RefreshCw className={`w-5 h-5 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      <div className="p-4 space-y-4 max-w-4xl mx-auto">
        {/* Connection Status */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-gray-400 mb-3 uppercase">Статус подключения</h2>
          <div className="flex items-center gap-3">
            {debugInfo?.signalRConnected ? (
              <>
                <Wifi className="w-6 h-6 text-green-400" />
                <span className="text-green-400 font-medium">SignalR подключён</span>
              </>
            ) : (
              <>
                <WifiOff className="w-6 h-6 text-red-400" />
                <span className="text-red-400 font-medium">SignalR отключён</span>
              </>
            )}
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="text-2xl font-bold text-indigo-400">{debugInfo?.totalChats || 0}</div>
            <div className="text-sm text-gray-400">Чатов</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="text-2xl font-bold text-indigo-400">{debugInfo?.totalMessages || 0}</div>
            <div className="text-sm text-gray-400">Сообщений</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="text-2xl font-bold text-yellow-400">{debugInfo?.pendingMessagesCount || 0}</div>
            <div className="text-sm text-gray-400">В очереди</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-4">
            <div className="text-2xl font-bold text-blue-400">{debugInfo?.cachedChatsCount || 0}</div>
            <div className="text-sm text-gray-400">В кэше</div>
          </div>
        </div>

        {/* User Info */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-gray-400 mb-3 uppercase">Информация</h2>
          <div className="space-y-2 text-sm font-mono">
            <div className="flex justify-between">
              <span className="text-gray-400">Пользователь:</span>
              <span>{debugInfo?.currentUser || 'N/A'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Выбранный чат:</span>
              <span className="truncate max-w-[200px]">{debugInfo?.selectedChat || 'N/A'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Уведомления:</span>
              <span className={debugInfo?.notificationPermission === 'granted' ? 'text-green-400' : 'text-yellow-400'}>
                {debugInfo?.notificationPermission}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Обновлено:</span>
              <span>{debugInfo?.timestamp ? new Date(debugInfo.timestamp).toLocaleTimeString() : 'N/A'}</span>
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-gray-400 mb-3 uppercase">Действия</h2>
          <div className="flex flex-wrap gap-2">
            <button
              onClick={testNotification}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg transition text-sm"
            >
              <Bell className="w-4 h-4" />
              Тест уведомлений
            </button>
            <button
              onClick={clearCache}
              className="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg transition text-sm"
            >
              <Trash2 className="w-4 h-4" />
              Очистить кэш
            </button>
          </div>
        </div>

        {/* Logs */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-gray-400 mb-3 uppercase">Логи</h2>
          <div className="bg-black rounded-lg p-3 max-h-64 overflow-y-auto font-mono text-xs">
            {logs.length === 0 ? (
              <span className="text-gray-500">Нет записей</span>
            ) : (
              logs.map((log, index) => (
                <div key={index} className="text-green-400 py-0.5">{log}</div>
              ))
            )}
          </div>
        </div>

        {/* Browser Info */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-gray-400 mb-3 uppercase">Браузер</h2>
          <p className="text-xs font-mono text-gray-500 break-all">
            {debugInfo?.browserInfo}
          </p>
        </div>
      </div>
    </div>
  );
};

