import { create } from 'zustand';
import { AuthResponse, LoginRequest, RegisterRequest, UserProfile } from '../types/auth';
import { authApi } from '../api/authApi';
import { signalRService } from '../services/signalRService';

interface AuthState {
  user: UserProfile | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;
  
  login: (data: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  loadUserProfile: () => Promise<void>;
  clearError: () => void;
  
  // Computed
  isAdmin: boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  token: localStorage.getItem('auth_token'),
  isLoading: false,
  error: null,

  login: async (data: LoginRequest) => {
    set({ isLoading: true, error: null });
    try {
      const response: AuthResponse = await authApi.login(data);
      localStorage.setItem('auth_token', response.token);
      localStorage.setItem('user_profile', JSON.stringify(response.user));
      
      // Connect to SignalR
      await signalRService.connect(response.token);
      
      set({ user: response.user, token: response.token, isLoading: false });
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Ошибка входа';
      set({ error: errorMessage, isLoading: false });
      throw error;
    }
  },

  register: async (data: RegisterRequest) => {
    set({ isLoading: true, error: null });
    try {
      const response: AuthResponse = await authApi.register(data);
      localStorage.setItem('auth_token', response.token);
      localStorage.setItem('user_profile', JSON.stringify(response.user));
      
      // Connect to SignalR
      await signalRService.connect(response.token);
      
      set({ user: response.user, token: response.token, isLoading: false });
    } catch (error: any) {
      const errorMessage = error.response?.data?.message || 'Ошибка регистрации';
      set({ error: errorMessage, isLoading: false });
      throw error;
    }
  },

  logout: async () => {
    await signalRService.disconnect();
    localStorage.removeItem('auth_token');
    localStorage.removeItem('user_profile');
    set({ user: null, token: null, error: null });
  },

  loadUserProfile: async () => {
    const token = get().token;
    if (!token) return;

    set({ isLoading: true });
    try {
      const user = await authApi.getUserProfile();
      set({ user, isLoading: false });
      
      // Connect to SignalR if not connected
      if (!signalRService.isConnected) {
        await signalRService.connect(token);
      }
    } catch (error: any) {
      set({ isLoading: false, error: 'Ошибка загрузки профиля' });
      // Token might be invalid, logout
      get().logout();
    }
  },

  clearError: () => set({ error: null }),

  // Computed property
  get isAdmin() {
    return get().user?.isAdmin || false;
  },
}));
