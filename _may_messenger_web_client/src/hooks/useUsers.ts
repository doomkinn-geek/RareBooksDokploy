import { useEffect, useState } from 'react';
import { UserProfile } from '../types/auth';
import { authApi } from '../api/authApi';

export const useUsers = () => {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadUsers = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await authApi.getAllUsers();
      setUsers(data);
    } catch (err: any) {
      console.error('[useUsers] Load error:', err);
      setError('Ошибка загрузки пользователей');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, []);

  return { users, isLoading, error, reload: loadUsers };
};

