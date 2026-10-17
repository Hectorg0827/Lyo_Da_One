import { create } from 'zustand';
import type { User, AuthState } from '@/types';
import { api, getAccessToken, clearTokens } from '@/lib/api';
import { hydrationFailureKind } from '@/lib/auth-hydration.mjs';
import { mergeGamificationProfile } from '@/lib/learner-stats.mjs';

// Ignore verification responses from an account already switched or signed out.
let authVersion = 0;

interface AuthStore extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, displayName: string) => Promise<void>;
  logout: () => void;
  setUser: (user: User) => void;
  updateUser: (updates: Partial<User>) => void;
  hydrate: () => Promise<void>;
  authVerificationError: boolean;
  enrichWithGamification: () => Promise<void>;
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: true,
  authVerificationError: false,

  login: async (email: string, password: string) => {
    const version = ++authVersion;
    set({ isLoading: true, authVerificationError: false });
    try {
      const { user, accessToken } = await api.auth.login(email, password);
      if (version !== authVersion) return;
      set({ user, token: accessToken, isAuthenticated: true, isLoading: false, authVerificationError: false });
      get().enrichWithGamification();
    } catch (err) {
      if (version === authVersion) set({ isLoading: false });
      throw err;
    }
  },

  signup: async (email: string, password: string, displayName: string) => {
    const version = ++authVersion;
    set({ isLoading: true, authVerificationError: false });
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
      if (version !== authVersion) return;
      set({ user, token: accessToken, isAuthenticated: true, isLoading: false, authVerificationError: false });
    } catch (err) {
      if (version === authVersion) set({ isLoading: false });
      throw err;
    }
  },

  logout: () => {
    ++authVersion;
    api.auth.logout().catch(() => {});
    clearTokens();
    set({ user: null, token: null, isAuthenticated: false, isLoading: false, authVerificationError: false });
  },

  setUser: (user) => set({ user }),

  updateUser: (updates) =>
    set((state) => ({
      user: state.user ? { ...state.user, ...updates } : null,
    })),

  hydrate: async () => {
    const version = ++authVersion;
    const token = getAccessToken();
    if (!token) {
      set({ user: null, token: null, isAuthenticated: false, isLoading: false, authVerificationError: false });
      return;
    }
    set({ isLoading: true, authVerificationError: false });
    try {
      const user = await api.auth.me();
      if (version !== authVersion) return;
      const current = getAccessToken();
      if (!current) {
        set({ user: null, token: null, isAuthenticated: false, isLoading: false, authVerificationError: false });
        return;
      }
      set({ user, token: current, isAuthenticated: true, isLoading: false, authVerificationError: false });
      void get().enrichWithGamification();
    } catch (error) {
      if (version !== authVersion) return;
      if (hydrationFailureKind(error) === 'invalid_session') {
        clearTokens();
        set({ user: null, token: null, isAuthenticated: false, isLoading: false, authVerificationError: false });
        return;
      }
      // 429/5xx/network errors are not proof of revoked credentials.
      // An unverified cold start remains unverified; do not invent identity.
      const current = getAccessToken();
      set((state) => ({
        user: state.isAuthenticated && current ? state.user : null,
        token: current,
        isAuthenticated: Boolean(current && state.isAuthenticated && state.user),
        isLoading: false,
        authVerificationError: Boolean(current),
      }));
    }
  },

  enrichWithGamification: async () => {
    const owner = get().user?.id;
    const originalToken = getAccessToken();
    if (!owner || !get().isAuthenticated) return;
    try {
      const overview = await api.gamification.overview();
      set((state) => {
        if (!state.user || !state.isAuthenticated || state.user.id !== owner ||
            getAccessToken() !== originalToken) return state;
        return {
          user: mergeGamificationProfile(state.user, overview),
        };
      });
    } catch {
      // gamification data is supplementary; fail silently
    }
  },
}));
