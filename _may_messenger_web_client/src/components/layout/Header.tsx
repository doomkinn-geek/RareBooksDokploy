import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../stores/authStore';
import { Settings, User } from 'lucide-react';

export const Header = () => {
  const navigate = useNavigate();
  const { user } = useAuthStore();

  return (
    <header className="bg-indigo-600 text-white px-6 py-4 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
          {user?.avatar ? (
            <img 
              src={user.avatar} 
              alt={user.displayName}
              className="w-full h-full rounded-full object-cover"
            />
          ) : (
            <User className="w-6 h-6" />
          )}
        </div>
        <div>
          <h1 className="font-semibold">{user?.displayName || 'May Messenger'}</h1>
          <p className="text-sm text-white/70">{user?.phoneNumber || ''}</p>
        </div>
      </div>
      
      <button
        onClick={() => navigate('/settings')}
        className="p-2 rounded-lg hover:bg-white/10 transition"
        title="Настройки"
      >
        <Settings className="w-5 h-5" />
      </button>
    </header>
  );
};
