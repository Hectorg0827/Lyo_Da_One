import { create } from 'zustand';
import type { User, AuthState } from '@/types';

interface AuthStore extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, displayName: string) => Promise<void>;
  logout: () => void;
  setUser: (user: User) => void;
  updateUser: (updates: Partial<User>) => void;
}

// Demo user for development
const demoUser: User = {
  id: 'user_1',
  email: 'demo@lyo.app',
  displayName: 'Alex Rivera',
  username: 'alexrivera',
  avatar: '',
  bio: 'Lifelong learner. Passionate about AI and education.',
  role: 'student',
  interests: ['AI', 'Machine Learning', 'Design', 'Music'],
  learningGoals: ['Master Python', 'Learn UI/UX Design'],
  streak: 12,
  xp: 4850,
  level: 15,
  coursesCompleted: 23,
  followersCount: 342,
  followingCount: 128,
  createdAt: '2024-06-01T00:00:00Z',
  isPremium: false,
};

export const useAuthStore = create<AuthStore>((set) => ({
  user: demoUser,
  token: 'demo_token',
  isAuthenticated: true,
  isLoading: false,

  login: async (_email: string, _password: string) => {
    set({ isLoading: true });
    await new Promise((r) => setTimeout(r, 800));
    set({ user: demoUser, token: 'demo_token', isAuthenticated: true, isLoading: false });
  },

  signup: async (_email: string, _password: string, displayName: string) => {
    set({ isLoading: true });
    await new Promise((r) => setTimeout(r, 800));
    set({
      user: { ...demoUser, displayName },
      token: 'demo_token',
      isAuthenticated: true,
      isLoading: false,
    });
  },

  logout: () => {
    if (typeof window !== 'undefined') localStorage.removeItem('lyo_token');
    set({ user: null, token: null, isAuthenticated: false });
  },

  setUser: (user) => set({ user }),
  updateUser: (updates) =>
    set((state) => ({
      user: state.user ? { ...state.user, ...updates } : null,
    })),
}));
