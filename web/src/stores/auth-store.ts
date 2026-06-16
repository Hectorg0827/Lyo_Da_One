import { create } from 'zustand';
import type { User, AuthState } from '@/types';
import { api, getAccessToken, clearTokens, adaptUser } from '@/lib/api';

interface AuthStore extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, displayName: string) => Promise<void>;
  logout: () => void;
  setUser: (user: User) => void;
  updateUser: (updates: Partial<User>) => void;
  hydrate: () => Promise<void>;
  enrichWithGamification: () => Promise<void>;
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: true,

  login: async (email: string, password: string) => {
    set({ isLoading: true });
    try {
      const { user, accessToken } = await api.auth.login(email, password);
      set({ user, token: accessToken, isAuthenticated: true, isLoading: false });
      get().enrichWithGamification();
    } catch (err) {
      set({ isLoading: false });
      throw err;
    }
  },

  signup: async (email: string, password: string, displayName: string) => {
    set({ isLoading: true });
    try {
      const nameParts = displayName.trim().split(' ');
      const firstName = nameParts[0] || displayName;
      const lastName = nameParts.slice(1).join(' ') || undefined;
      const username = displayName.toLowerCase().replace(/[^a-z0-9]/g, '') + Math.floor(Math.random() * 1000);

      const { user, accessToken } = await api.auth.register({
        email,
        username,
        password,
        confirmPassword: password,
        firstName,
        lastName,
      });
      set({ user, token: accessToken, isAuthenticated: true, isLoading: false });
    } catch (err) {
      set({ isLoading: false });
      throw err;
    }
  },

  logout: () => {
    api.auth.logout().catch(() => {});
    clearTokens();
    set({ user: null, token: null, isAuthenticated: false });
  },

  setUser: (user) => set({ user }),

  updateUser: (updates) =>
    set((state) => ({
      user: state.user ? { ...state.user, ...updates } : null,
    })),

  hydrate: async () => {
    const token = getAccessToken();
    if (!token) {
      set({ isLoading: false, isAuthenticated: false });
      return;
    }
    try {
      const user = await api.auth.me();
      set({ user, token, isAuthenticated: true, isLoading: false });
      get().enrichWithGamification();
    } catch {
      clearTokens();
      set({ user: null, token: null, isAuthenticated: false, isLoading: false });
    }
  },

  enrichWithGamification: async () => {
    try {
      const overview = await api.gamification.overview();
      const userLevel = overview.user_level as Record<string, unknown> | undefined;
      const xpSummary = overview.xp_summary as Record<string, unknown> | undefined;
      const streaks = overview.streaks as Record<string, unknown> | undefined;
      const achievements = overview.achievements as Record<string, unknown> | undefined;

      set((state) => {
        if (!state.user) return state;
        return {
          user: {
            ...state.user,
            level: (userLevel?.level as number) || state.user.level,
            xp: (xpSummary?.total as number) || (userLevel?.total_xp as number) || state.user.xp,
            streak: (streaks?.current as number) || state.user.streak,
            coursesCompleted: (achievements?.completed as number) || state.user.coursesCompleted,
          },
        };
      });
    } catch {
      // gamification data is supplementary; fail silently
    }
  },
}));
