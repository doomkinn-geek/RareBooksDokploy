import { useState, useMemo } from 'react';
import { UserProfile } from '../../types/auth';
import { Search } from 'lucide-react';

interface UserSelectProps {
  users: UserProfile[];
  selectedUserIds: string[];
  onSelectionChange: (userIds: string[]) => void;
  multiSelect?: boolean;
  currentUserId?: string;
}

export const UserSelect = ({ 
  users, 
  selectedUserIds, 
  onSelectionChange, 
  multiSelect = false,
  currentUserId 
}: UserSelectProps) => {
  const [searchQuery, setSearchQuery] = useState('');

  // Filter out current user and search
  const filteredUsers = useMemo(() => {
    return users
      .filter(user => user.id !== currentUserId)
      .filter(user => 
        user.displayName.toLowerCase().includes(searchQuery.toLowerCase()) ||
        user.phoneNumber.includes(searchQuery)
      );
  }, [users, searchQuery, currentUserId]);

  const handleUserClick = (userId: string) => {
    if (multiSelect) {
      if (selectedUserIds.includes(userId)) {
        onSelectionChange(selectedUserIds.filter(id => id !== userId));
      } else {
        onSelectionChange([...selectedUserIds, userId]);
      }
    } else {
      onSelectionChange([userId]);
    }
  };

  const isSelected = (userId: string) => selectedUserIds.includes(userId);

  return (
    <div className="flex flex-col h-full">
      {/* Search */}
      <div className="p-4 border-b">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Поиск по имени или телефону..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* User List */}
      <div className="flex-1 overflow-y-auto">
        {filteredUsers.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-500">
            <p>Пользователи не найдены</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {filteredUsers.map((user) => {
              const selected = isSelected(user.id);
              return (
                <div
                  key={user.id}
                  onClick={() => handleUserClick(user.id)}
                  className={`flex items-center gap-3 p-4 cursor-pointer hover:bg-gray-50 transition ${
                    selected ? 'bg-indigo-50' : ''
                  }`}
                >
                  {multiSelect && (
                    <input
                      type="checkbox"
                      checked={selected}
                      onChange={() => {}}
                      className="w-5 h-5 text-indigo-600 rounded focus:ring-indigo-500"
                    />
                  )}
                  
                  <div className="w-10 h-10 bg-indigo-600 rounded-full flex items-center justify-center text-white font-semibold flex-shrink-0">
                    {user.avatar ? (
                      <img 
                        src={user.avatar} 
                        alt={user.displayName}
                        className="w-full h-full rounded-full object-cover"
                      />
                    ) : (
                      <span>{user.displayName[0]?.toUpperCase()}</span>
                    )}
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-gray-900 truncate">
                      {user.displayName}
                    </p>
                    <p className="text-sm text-gray-600 truncate">
                      {user.phoneNumber}
                    </p>
                  </div>

                  {selected && !multiSelect && (
                    <div className="w-6 h-6 bg-indigo-600 rounded-full flex items-center justify-center">
                      <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                      </svg>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

