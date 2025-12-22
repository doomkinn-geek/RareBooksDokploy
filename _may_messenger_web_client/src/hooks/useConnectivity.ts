/**
 * Hook для использования ConnectivityService в компонентах
 */

import { useState, useEffect } from 'react';
import { connectivityService } from '../services/connectivityService';

export const useConnectivity = () => {
  const [isConnected, setIsConnected] = useState(connectivityService.getIsConnected());

  useEffect(() => {
    // Подписаться на изменения подключения
    const unsubscribe = connectivityService.onConnectionChange((connected) => {
      setIsConnected(connected);
    });

    return () => {
      unsubscribe();
    };
  }, []);

  const checkConnectivity = async () => {
    return await connectivityService.checkConnectivity();
  };

  return {
    isConnected,
    checkConnectivity,
  };
};

