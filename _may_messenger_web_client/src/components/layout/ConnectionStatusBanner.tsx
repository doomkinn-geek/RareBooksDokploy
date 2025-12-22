import { useEffect, useState } from 'react';
import { WifiOff, Wifi } from 'lucide-react';
import { connectivityService } from '../../services/connectivityService';

export const ConnectionStatusBanner = () => {
  const [isConnected, setIsConnected] = useState(connectivityService.getIsConnected());
  const [showBanner, setShowBanner] = useState(!isConnected);

  useEffect(() => {
    // Подписаться на изменения подключения
    const unsubscribe = connectivityService.onConnectionChange((connected) => {
      setIsConnected(connected);
      setShowBanner(!connected);

      // Если подключение восстановлено, показать баннер на 3 секунды
      if (connected) {
        setTimeout(() => {
          setShowBanner(false);
        }, 3000);
      }
    });

    return () => {
      unsubscribe();
    };
  }, []);

  if (!showBanner) {
    return null;
  }

  return (
    <div
      className={`flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium ${
        isConnected
          ? 'bg-green-500 text-white'
          : 'bg-yellow-500 text-gray-900'
      }`}
    >
      {isConnected ? (
        <>
          <Wifi className="w-4 h-4" />
          <span>Подключение восстановлено</span>
        </>
      ) : (
        <>
          <WifiOff className="w-4 h-4" />
          <span>Нет подключения к интернету</span>
        </>
      )}
    </div>
  );
};

