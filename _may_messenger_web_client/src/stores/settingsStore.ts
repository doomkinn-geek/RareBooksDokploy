import { create } from 'zustand';
import { InviteLink } from '../types/message';
import { authApi } from '../api/authApi';

interface SettingsState {
  inviteLinks: InviteLink[];
  isLoading: boolean;
  isCreating: boolean;
  error: string | null;
  
  loadInviteLinks: () => Promise<void>;
  createInviteLink: () => Promise<{ code: string; inviteLink: string } | null>;
  refreshInvites: () => Promise<void>;
  clearError: () => void;
  
  // Computed properties
  validInviteLinks: InviteLink[];
}

export const useSettingsStore = create<SettingsState>((set, get) => ({
  inviteLinks: [],
  isLoading: false,
  isCreating: false,
  error: null,

  loadInviteLinks: async () => {
    set({ isLoading: true, error: null });
    try {
      const links = await authApi.getMyInviteLinks();
      set({ inviteLinks: links, isLoading: false });
    } catch (error: any) {
      console.error('[SettingsStore] Load invite links error:', error);
      set({ error: 'Ошибка загрузки кодов приглашения', isLoading: false });
    }
  },

  createInviteLink: async () => {
    set({ isCreating: true, error: null });
    try {
      const newLink = await authApi.createInviteLink();
      
      // Reload invite links to get the full data
      await get().loadInviteLinks();
      
      set({ isCreating: false });
      return newLink;
    } catch (error: any) {
      console.error('[SettingsStore] Create invite link error:', error);
      const errorMessage = error.response?.data?.message || 'Ошибка создания кода приглашения';
      set({ error: errorMessage, isCreating: false });
      return null;
    }
  },

  refreshInvites: async () => {
    await get().loadInviteLinks();
  },

  clearError: () => set({ error: null }),

  // Computed properties
  get validInviteLinks() {
    const now = new Date();
    return get().inviteLinks.filter(link => {
      if (link.isUsed) return false;
      if (link.expiresAt && new Date(link.expiresAt) < now) return false;
      return true;
    });
  },
}));

