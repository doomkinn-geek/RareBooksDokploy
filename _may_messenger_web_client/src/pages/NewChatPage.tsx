import { useState, useEffect } from 'react';
import { X, User, Loader2, Search } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { searchService, User as SearchUser } from '../services/searchService';
import { useChatStore } from '../stores/chatStore';
import { chatApi } from '../api/chatApi';

export const NewChatPage = () => {
  const [query, setQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [users, setUsers] = useState<SearchUser[]>([]);
  const { selectChat } = useChatStore();
  const navigate = useNavigate();

  // Загрузить контакты при монтировании
  useEffect(() => {
    loadContacts();
  }, []);

  // Поиск с debounce
  useEffect(() => {
    if (!query.trim()) {
      loadContacts();
      return;
    }

    const timeoutId = setTimeout(async () => {
      await searchUsers(query);
    }, 300);

    return () => clearTimeout(timeoutId);
  }, [query]);

  const loadContacts = async () => {
    setIsLoading(true);
    setError(null);

    try {
      // Загрузить всех пользователей (или контакты, если есть такой endpoint)
      const results = await searchService.searchUsers('', true); // contactsOnly = true
      setUsers(results);
    } catch (err: any) {
      console.error('[NewChatPage] Error loading contacts:', err);
      setError(err.response?.data?.message || 'Ошибка загрузки контактов');
    } finally {
      setIsLoading(false);
    }
  };

  const searchUsers = async (searchQuery: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const results = await searchService.searchUsers(searchQuery, false);
      setUsers(results);
    } catch (err: any) {
      console.error('[NewChatPage] Search error:', err);
      setError(err.response?.data?.message || 'Ошибка поиска');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUserClick = async (user: SearchUser) => {
    setIsCreating(true);
    setError(null);

    try {
      // Создать или получить приватный чат с этим пользователем
      const chat = await chatApi.createOrGetPrivateChat(user.id);
      selectChat(chat.id);
      navigate('/');
    } catch (err: any) {
      console.error('[NewChatPage] Error creating/getting chat:', err);
      setError(err.response?.data?.message || 'Ошибка создания чата');
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 p-4">
        <div className="flex items-center gap-3 mb-4">
          <button
            onClick={() => navigate('/')}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            aria-label="Назад"
          >
            <X className="w-5 h-5 text-gray-600" />
          </button>
          <h1 className="text-xl font-semibold text-gray-900">Новый чат</h1>
        </div>

        {/* Search Input */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Поиск по имени или номеру..."
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="mx-4 mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}

      {/* Users List */}
      <div className="flex-1 overflow-y-auto">
        {isLoading && (
          <div className="flex items-center justify-center h-32">
            <Loader2 className="w-8 h-8 text-indigo-600 animate-spin" />
          </div>
        )}

        {!isLoading && users.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-gray-500">
            <User className="w-16 h-16 mb-4 text-gray-300" />
            <p className="text-lg font-medium">Нет пользователей</p>
            <p className="text-sm mt-2">Попробуйте изменить запрос</p>
          </div>
        )}

        {!isLoading && users.length > 0 && (
          <div className="bg-white divide-y divide-gray-100 mt-4">
            {users.map((user) => (
              <button
                key={user.id}
                onClick={() => handleUserClick(user)}
                disabled={isCreating}
                className="w-full px-4 py-3 hover:bg-gray-50 transition text-left flex items-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <div className="w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0">
                  <User className="w-5 h-5 text-indigo-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 truncate">{user.displayName}</p>
                  <p className="text-sm text-gray-500 truncate">{user.phoneNumber}</p>
                </div>
                {user.isOnline && (
                  <div className="w-2 h-2 rounded-full bg-green-500 flex-shrink-0" />
                )}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

