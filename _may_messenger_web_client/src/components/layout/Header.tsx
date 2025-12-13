import { useAuthStore } from '../../stores/authStore';
import { LogOut, User } from 'lucide-react';

export const Header = () => {
  const { user, logout } = useAuthStore();

  const handleLogout = async () => {
    if (confirm('Вы уверены, что хотите выйти?')) {
      await logout();
      window.location.href = '/login';
    }
  };

  return (
    <header className="bg-indigo-600 text-white px-6 py-4 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
          <User className="w-6 h-6" />
        </div>
        <div>
          <h1 className="font-semibold">{user?.displayName}</h1>
          <p className="text-sm text-white/70">{user?.phoneNumber}</p>
        </div>
      </div>
      
      <button
        onClick={handleLogout}
        className="p-2 rounded-lg hover:bg-white/10 transition"
        title="Выйти"
      >
        <LogOut className="w-5 h-5" />
      </button>
    </header>
  );
};
