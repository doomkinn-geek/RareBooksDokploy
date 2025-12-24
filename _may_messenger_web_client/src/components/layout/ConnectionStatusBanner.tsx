import { useState, useEffect } from 'react';
import { signalRService } from '../../services/signalRService';
import { Wifi, WifiOff, Loader2 } from 'lucide-react';

type ConnectionState = 'connected' | 'disconnected' | 'reconnecting';

export const ConnectionStatusBanner = () => {
  const [connectionState, setConnectionState] = useState<ConnectionState>(
    signalRService.isConnected ? 'connected' : 'disconnected'
  );
  const [showBanner, setShowBanner] = useState(false);

  useEffect(() => {
    // Poll connection state
    const interval = setInterval(() => {
      const isConnected = signalRService.isConnected;
      
      if (isConnected) {
        if (connectionState !== 'connected') {
          setConnectionState('connected');
          // Show "Connected" briefly then hide
          setShowBanner(true);
          setTimeout(() => setShowBanner(false), 2000);
        }
      } else {
        setConnectionState('disconnected');
        setShowBanner(true);
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [connectionState]);

  if (!showBanner) return null;

  const getStatusContent = () => {
    switch (connectionState) {
      case 'connected':
        return (
          <>
            <Wifi className="w-4 h-4" />
            <span>Подключено</span>
          </>
        );
      case 'reconnecting':
        return (
          <>
            <Loader2 className="w-4 h-4 animate-spin" />
            <span>Переподключение...</span>
          </>
        );
      case 'disconnected':
        return (
          <>
            <WifiOff className="w-4 h-4" />
            <span>Нет подключения</span>
          </>
        );
    }
  };

  const getBannerStyles = () => {
    switch (connectionState) {
      case 'connected':
        return 'bg-green-500 text-white';
      case 'reconnecting':
        return 'bg-yellow-500 text-white';
      case 'disconnected':
        return 'bg-red-500 text-white';
    }
  };

  return (
    <div 
      className={`fixed top-0 left-0 right-0 z-50 py-2 px-4 flex items-center justify-center gap-2 text-sm font-medium transition-all duration-300 ${getBannerStyles()}`}
    >
      {getStatusContent()}
    </div>
  );
};
