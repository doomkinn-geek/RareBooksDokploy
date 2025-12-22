import { useState, useEffect, useCallback } from 'react';
import { Search, X, MessageCircle, User, Loader2 } from 'lucide-react';
import { searchService, User as SearchUser, MessageSearchResult } from '../services/searchService';
import { useChatStore } from '../stores/chatStore';
import { useNavigate } from 'react-router-dom';
import { chatApi } from '../api/chatApi';

export const SearchPage = () => {
  const [query, setQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [userResults, setUserResults] = useState<SearchUser[]>([]);
  const [messageResults, setMessageResults] = useState<MessageSearchResult[]>([]);
  const { selectChat } = useChatStore();
  const navigate = useNavigate();

  // Debounced search
  useEffect(() => {
    if (!query.trim()) {
      setUserResults([]);
      setMessageResults([]);
      setError(null);
      return;
    }

    const timeoutId = setTimeout(async () => {
      await performSearch(query);
    }, 300); // 300ms debounce

    return () => clearTimeout(timeoutId);
  }, [query]);

  const performSearch = async (searchQuery: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const results = await searchService.searchAll(searchQuery);
      setUserResults(results.users);
      setMessageResults(results.messages);
    } catch (err: any) {
      console.error('[SearchPage] Search error:', err);
      setError(err.response?.data?.message || 'Ошибка поиска');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUserClick = async (user: SearchUser) => {
    try {
      // Создать или получить приватный чат с этим пользователем
      const chat = await chatApi.createOrGetPrivateChat(user.id);
      selectChat(chat.id);
      navigate('/');
    } catch (err: any) {
      console.error('[SearchPage] Error creating/getting chat:', err);
      setError(err.response?.data?.message || 'Ошибка создания чата');
    }
  };

  const handleMessageClick = (result: MessageSearchResult) => {
    selectChat(result.chatId);
    navigate('/');
    // TODO: можно добавить прокрутку к конкретному сообщению
  };

  const handleClearQuery = () => {
    setQuery('');
  };

  const hasResults = userResults.length > 0 || messageResults.length > 0;

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header with search input */}
      <div className="bg-white border-b border-gray-200 p-4">
        <div className="flex items-center gap-3">
          <button
            onClick={() => navigate('/')}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            aria-label="Назад"
          >
            <X className="w-5 h-5 text-gray-600" />
          </button>

          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Поиск контактов и сообщений..."
              className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              autoFocus
            />
            {query && (
              <button
                onClick={handleClearQuery}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 rounded-full transition"
                aria-label="Очистить"
              >
                <X className="w-4 h-4 text-gray-400" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Results */}
      <div className="flex-1 overflow-y-auto">
        {!query.trim() && (
          <div className="flex flex-col items-center justify-center h-full text-gray-500">
            <Search className="w-16 h-16 mb-4 text-gray-400" />
            <p className="text-lg font-medium">Начните вводить для поиска</p>
            <p className="text-sm mt-2">Контакты • Сообщения</p>
          </div>
        )}

        {isLoading && (
          <div className="flex items-center justify-center h-32">
            <Loader2 className="w-8 h-8 text-indigo-600 animate-spin" />
          </div>
        )}

        {error && (
          <div className="flex flex-col items-center justify-center h-32 px-4">
            <div className="text-red-500 text-center">
              <p className="font-medium mb-2">Ошибка поиска</p>
              <p className="text-sm">{error}</p>
            </div>
          </div>
        )}

        {!isLoading && !error && query.trim() && !hasResults && (
          <div className="flex flex-col items-center justify-center h-full text-gray-500">
            <Search className="w-16 h-16 mb-4 text-gray-300" />
            <p className="text-lg font-medium">Ничего не найдено</p>
            <p className="text-sm mt-2">Попробуйте изменить запрос</p>
          </div>
        )}

        {!isLoading && !error && hasResults && (
          <div className="py-4">
            {/* User Results */}
            {userResults.length > 0 && (
              <div className="mb-6">
                <div className="px-4 mb-3">
                  <h3 className="text-sm font-semibold text-indigo-600">
                    Контакты ({userResults.length})
                  </h3>
                </div>
                <div className="bg-white divide-y divide-gray-100">
                  {userResults.map((user) => (
                    <button
                      key={user.id}
                      onClick={() => handleUserClick(user)}
                      className="w-full px-4 py-3 hover:bg-gray-50 transition text-left flex items-center gap-3"
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
              </div>
            )}

            {/* Message Results */}
            {messageResults.length > 0 && (
              <div>
                <div className="px-4 mb-3">
                  <h3 className="text-sm font-semibold text-indigo-600">
                    Сообщения ({messageResults.length})
                  </h3>
                </div>
                <div className="bg-white divide-y divide-gray-100">
                  {messageResults.map((result) => (
                    <button
                      key={result.messageId}
                      onClick={() => handleMessageClick(result)}
                      className="w-full px-4 py-3 hover:bg-gray-50 transition text-left"
                    >
                      <div className="flex items-start gap-3">
                        <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0 mt-1">
                          <MessageCircle className="w-5 h-5 text-gray-600" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="font-medium text-gray-900 mb-1">{result.chatTitle}</p>
                          <p className="text-sm text-gray-700 line-clamp-2 mb-1">
                            {result.messageContent}
                          </p>
                          <p className="text-xs text-gray-500">{result.senderName}</p>
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

