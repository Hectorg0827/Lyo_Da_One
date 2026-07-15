import type { User } from '@/types';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoapp.com';

// ── Token management ─────────────────────────────────────────────────────────

export function getAccessToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('lyo_token');
}

export function getRefreshToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('lyo_refresh_token');
}

export function setTokens(access: string, refresh?: string | null) {
  if (typeof window === 'undefined') return;
  localStorage.setItem('lyo_token', access);
  if (refresh) localStorage.setItem('lyo_refresh_token', refresh);
}

export function clearTokens() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem('lyo_token');
  localStorage.removeItem('lyo_refresh_token');
}

// ── Core request ─────────────────────────────────────────────────────────────

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  endpoint: string,
  options: RequestInit & { skipAuth?: boolean } = {}
): Promise<T> {
  const { skipAuth, ...fetchOptions } = options;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(fetchOptions.headers as Record<string, string>),
  };

  if (!skipAuth) {
    const token = getAccessToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_URL}${endpoint}`, {
    ...fetchOptions,
    headers,
  });

  if (res.status === 401 && !skipAuth) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      headers['Authorization'] = `Bearer ${getAccessToken()}`;
      const retry = await fetch(`${API_URL}${endpoint}`, {
        ...fetchOptions,
        headers,
      });
      if (retry.ok) {
        if (retry.status === 204) return undefined as T;
        return retry.json();
      }
    }
    clearTokens();
    if (typeof window !== 'undefined') window.location.href = '/auth/login';
    throw new ApiError('Session expired', 401);
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: 'Request failed' }));
    throw new ApiError(body.detail || body.message || `HTTP ${res.status}`, res.status);
  }

  if (res.status === 204) return undefined as T;
  return res.json();
}

async function tryRefreshToken(): Promise<boolean> {
  const refresh = getRefreshToken();
  if (!refresh) return false;
  try {
    const res = await fetch(`${API_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    setTokens(data.access_token, data.refresh_token);
    return true;
  } catch {
    return false;
  }
}

// ── Adapters (backend → frontend types) ──────────────────────────────────────

export function adaptUser(raw: Record<string, unknown>): User {
  const firstName = (raw.first_name as string) || '';
  const lastName = (raw.last_name as string) || '';
  const displayName = [firstName, lastName].filter(Boolean).join(' ') || (raw.username as string) || 'User';

  return {
    id: String(raw.id ?? ''),
    email: (raw.email as string) || '',
    displayName,
    username: (raw.username as string) || '',
    avatar: (raw.avatar_url as string) || '',
    bio: (raw.bio as string) || '',
    role: 'student',
    interests: (raw.interests as string[]) || [],
    learningGoals: (raw.learning_goals as string[]) || [],
    streak: (raw.streak as number) || 0,
    xp: (raw.xp as number) || (raw.total_xp as number) || 0,
    level: (raw.level as number) || (raw.current_level as number) || 1,
    coursesCompleted: (raw.courses_completed as number) || 0,
    followersCount: (raw.followers_count as number) || 0,
    followingCount: (raw.following_count as number) || 0,
    createdAt: (raw.created_at as string) || new Date().toISOString(),
    isPremium: (raw.is_premium as boolean) || false,
  };
}

// ── API methods ──────────────────────────────────────────────────────────────

export const api = {
  // ── Auth ──
  auth: {
    async login(email: string, password: string) {
      const data = await request<{
        user: Record<string, unknown>;
        access_token: string;
        refresh_token?: string;
      }>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
        skipAuth: true,
      });
      setTokens(data.access_token, data.refresh_token);
      return { user: adaptUser(data.user), accessToken: data.access_token };
    },

    async register(params: {
      email: string;
      username: string;
      password: string;
      confirmPassword: string;
      firstName?: string;
      lastName?: string;
    }) {
      const data = await request<{
        user: Record<string, unknown>;
        access_token: string;
        refresh_token?: string;
      }>('/auth/register', {
        method: 'POST',
        body: JSON.stringify({
          email: params.email,
          username: params.username,
          password: params.password,
          confirm_password: params.confirmPassword,
          first_name: params.firstName,
          last_name: params.lastName,
        }),
        skipAuth: true,
      });
      setTokens(data.access_token, data.refresh_token);
      return { user: adaptUser(data.user), accessToken: data.access_token };
    },

    async me() {
      const data = await request<Record<string, unknown>>('/auth/me');
      return adaptUser(data);
    },

    async updateProfile(updates: { full_name?: string; bio?: string; avatar_url?: string }) {
      const data = await request<Record<string, unknown>>('/auth/profile', {
        method: 'PUT',
        body: JSON.stringify(updates),
      });
      return adaptUser(data);
    },

    async logout() {
      try {
        await request('/auth/logout', { method: 'POST' });
      } finally {
        clearTokens();
      }
    },
  },

  // ── AI Chat ──
  chat: {
    async send(text: string, history?: { role: string; content: string }[]) {
      return request<{ answer_block: unknown; metadata: unknown }>('/api/v1/lyo2/chat', {
        method: 'POST',
        body: JSON.stringify({ text, history }),
      });
    },

    stream(
      text: string,
      history: { role: string; content: string }[] | undefined,
      onChunk: (data: Record<string, unknown>) => void,
      onDone: () => void,
      onError: (err: Error) => void
    ): AbortController {
      const controller = new AbortController();
      const token = getAccessToken();

      fetch(`${API_URL}/api/v1/lyo2/chat/stream`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ text, history }),
        signal: controller.signal,
      })
        .then(async (res) => {
          if (!res.ok) throw new Error(`Stream failed: ${res.status}`);
          const reader = res.body?.getReader();
          if (!reader) throw new Error('No response body');
          const decoder = new TextDecoder();
          let buffer = '';

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });

            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed || !trimmed.startsWith('data:')) continue;
              const payload = trimmed.slice(5).trim();
              if (payload === '[DONE]') {
                onDone();
                return;
              }
              try {
                onChunk(JSON.parse(payload));
              } catch {
                // skip malformed JSON
              }
            }
          }
          onDone();
        })
        .catch((err) => {
          if (err.name !== 'AbortError') onError(err);
        });

      return controller;
    },

    async sendSimple(message: string, provider?: string) {
      return request<{ response: string; suggestions?: { text: string }[] }>('/api/v1/ai/chat', {
        method: 'POST',
        body: JSON.stringify({ message, provider: provider || 'gemini' }),
      });
    },
  },

  // ── Feed / Community ──
  feed: {
    async list(page = 1, perPage = 20) {
      return request<{ posts: Record<string, unknown>[]; total: number; page: number }>(
        `/feed?page=${page}&per_page=${perPage}`
      );
    },

    async publicFeed(page = 1, perPage = 20) {
      return request<{ posts: Record<string, unknown>[]; total: number }>(
        `/feed/public?page=${page}&per_page=${perPage}`
      );
    },

    async get(postId: string) {
      return request<Record<string, unknown>>(`/posts/${postId}`);
    },

    async create(content: string, mediaUrls?: string[]) {
      return request<Record<string, unknown>>('/posts', {
        method: 'POST',
        body: JSON.stringify({
          content,
          post_type: mediaUrls && mediaUrls.length > 0 ? 'image' : 'text',
          image_url: mediaUrls?.[0],
        }),
      });
    },

    async like(postId: string) {
      return request('/posts/' + postId + '/reactions', {
        method: 'POST',
        body: JSON.stringify({ post_id: Number(postId), reaction_type: 'like' }),
      });
    },

    async unlike(postId: string) {
      return request(`/posts/${postId}/reactions`, { method: 'DELETE' });
    },

    async comment(postId: string, content: string) {
      return request<Record<string, unknown>>('/comments', {
        method: 'POST',
        body: JSON.stringify({ post_id: Number(postId), content }),
      });
    },

    async deleteComment(commentId: string) {
      return request(`/comments/${commentId}`, { method: 'DELETE' });
    },
  },

  // ── Users ──
  users: {
    async get(userId: string) {
      const data = await request<Record<string, unknown>>(`/auth/users/${userId}`);
      return adaptUser(data);
    },

    async posts(userId: string, page = 1) {
      return request<{ posts: Record<string, unknown>[]; total: number }>(
        `/users/${userId}/posts?page=${page}`
      );
    },

    async stats(userId: string) {
      return request<Record<string, unknown>>(`/users/${userId}/stats`);
    },

    async follow(userId: string) {
      return request('/follow', {
        method: 'POST',
        body: JSON.stringify({ following_id: Number(userId) }),
      });
    },

    async unfollow(userId: string) {
      return request(`/follow/${userId}`, { method: 'DELETE' });
    },
  },

  // ── Courses ──
  courses: {
    async list(skip = 0, limit = 20, subject?: string, difficulty?: string) {
      const params = new URLSearchParams({ skip: String(skip), limit: String(limit) });
      if (subject) params.set('subject', subject);
      if (difficulty) params.set('difficulty', difficulty);
      return request<Record<string, unknown>[]>(`/api/v1/learning/courses?${params}`);
    },

    async get(courseId: string) {
      return request<Record<string, unknown>>(`/api/v1/learning/courses/${courseId}`);
    },

    async create(data: Record<string, unknown>) {
      return request<Record<string, unknown>>('/api/v1/learning/courses', {
        method: 'POST',
        body: JSON.stringify(data),
      });
    },

    async generate(topic: string, difficulty = 'beginner', durationHours = 2) {
      return request<{ task_id: string; status: string }>('/api/v1/learning/courses/generate', {
        method: 'POST',
        body: JSON.stringify({
          topic,
          difficulty,
          duration_hours: durationHours,
          include_exercises: true,
          include_assessments: true,
        }),
      });
    },
  },

  // ── Clips ──
  clips: {
    async list(page = 1, perPage = 20) {
      return request<{ clips: Record<string, unknown>[]; total: number }>(
        `/api/v1/clips?page=${page}&per_page=${perPage}`
      );
    },

    async discover(page = 1, perPage = 20, subject?: string) {
      const params = new URLSearchParams({ page: String(page), per_page: String(perPage) });
      if (subject) params.set('subject', subject);
      return request<{ clips: Record<string, unknown>[]; total: number }>(
        `/api/v1/clips/discover?${params}`
      );
    },

    async get(clipId: string) {
      return request<{ clip: Record<string, unknown> }>(`/api/v1/clips/${clipId}`);
    },

    async create(data: Record<string, unknown>) {
      return request<{ clip: Record<string, unknown> }>('/api/v1/clips', {
        method: 'POST',
        body: JSON.stringify(data),
      });
    },

    async like(clipId: string) {
      return request<{ isLiked: boolean; likeCount: number }>(`/api/v1/clips/${clipId}/like`, {
        method: 'POST',
      });
    },

    async save(clipId: string) {
      return request<{ isSaved: boolean }>(`/api/v1/clips/${clipId}/save`, {
        method: 'POST',
      });
    },

    async view(clipId: string) {
      return request(`/api/v1/clips/${clipId}/view`, { method: 'POST' });
    },
  },

  // ── Stories ──
  stories: {
    async list() {
      return request<{ stories: Record<string, unknown>[]; my_story?: Record<string, unknown> }>(
        '/api/v1/stories'
      );
    },

    async get(storyId: string) {
      return request<Record<string, unknown>>(`/api/v1/stories/${storyId}`);
    },

    async create(data: { media_url: string; media_type?: string; caption?: string; tags?: string[] }) {
      return request<Record<string, unknown>>('/api/v1/stories', {
        method: 'POST',
        body: JSON.stringify(data),
      });
    },

    async seen(storyId: string) {
      return request(`/api/v1/stories/${storyId}/seen`, { method: 'POST' });
    },
  },

  // ── Gamification ──
  gamification: {
    async overview() {
      return request<Record<string, unknown>>('/gamification/overview');
    },


    async stats() {
      return request<Record<string, unknown>>('/gamification/stats');
    },

    async level() {
      return request<Record<string, unknown>>('/gamification/level');
    },

    async xpSummary() {
      return request<Record<string, unknown>>('/gamification/xp/summary');
    },

    async achievements(completedOnly = false) {
      return request<Record<string, unknown>[]>(
        `/gamification/my-achievements?completed_only=${completedOnly}`
      );
    },

    async streaks() {
      return request<Record<string, unknown>[]>('/gamification/streaks');
    },

    async leaderboard(type = 'xp', period = 'weekly', limit = 20) {
      return request<Record<string, unknown>>(
        `/gamification/leaderboards/${type}?period=${period}&limit=${limit}`
      );
    },
  },

  // ── Messages (DMs) ──
  messages: {
    async conversations() {
      return request<{ conversations: Record<string, unknown>[] }>('/messages/conversations');
    },

    async getMessages(conversationId: string, page = 1) {
      return request<{ messages: Record<string, unknown>[]; total: number }>(
        `/messages/conversations/${conversationId}?page=${page}`
      );
    },

    async createConversation(participantIds: number[]) {
      return request<Record<string, unknown>>('/messages/conversations', {
        method: 'POST',
        body: JSON.stringify({ participant_ids: participantIds }),
      });
    },

    async sendMessage(conversationId: string, content: string) {
      return request<Record<string, unknown>>(
        `/messages/conversations/${conversationId}/messages`,
        { method: 'POST', body: JSON.stringify({ content }) }
      );
    },

    async markRead(conversationId: string) {
      return request('/messages/conversations/' + conversationId + '/read', { method: 'POST' });
    },
  },

  // ── Community (Groups & Events) ──
  community: {
    async groups() {
      return request<Record<string, unknown>[]>('/community/study-groups');
    },

    async group(groupId: string) {
      return request<Record<string, unknown>>(`/community/study-groups/${groupId}`);
    },

    async joinGroup(groupId: string) {
      return request(`/community/study-groups/${groupId}/join`, { method: 'POST' });
    },

    async leaveGroup(groupId: string) {
      return request(`/community/study-groups/${groupId}/leave`, { method: 'DELETE' });
    },

    async events() {
      return request<Record<string, unknown>[]>('/community/events');
    },

    async event(eventId: string) {
      return request<Record<string, unknown>>(`/community/events/${eventId}`);
    },

    async attendEvent(eventId: string) {
      return request(`/community/events/${eventId}/attend`, { method: 'POST' });
    },

    async unattendEvent(eventId: string) {
      return request(`/community/events/${eventId}/attend`, { method: 'DELETE' });
    },

    async stats() {
      return request<Record<string, number>>('/community/stats');
    },

    // ── Community posts — the same store iOS renders (community/posts),
    //    NOT the separate /feed store; one account, one feed everywhere. ──
    async posts(page = 1, limit = 20, sortBy: 'recent' | 'popular' | 'trending' = 'recent') {
      return request<{
        items: Record<string, unknown>[];
        page: number;
        limit: number;
        total_count: number;
        total_pages: number;
      }>(`/community/posts?page=${page}&limit=${limit}&sort_by=${sortBy}`);
    },

    async post(postId: string) {
      return request<Record<string, unknown>>(`/community/posts/${postId}`);
    },

    async createPost(payload: {
      content: string;
      tags?: string[];
      media_urls?: string[];
      post_type?: string;
    }) {
      return request<Record<string, unknown>>('/community/posts', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
    },

    async togglePostLike(postId: string) {
      return request<{ liked: boolean; like_count: number }>(
        `/community/posts/${postId}/like`,
        { method: 'POST' }
      );
    },

    async togglePostBookmark(postId: string) {
      return request<{ bookmarked: boolean }>(
        `/community/posts/${postId}/bookmark`,
        { method: 'POST' }
      );
    },

    async comments(postId: string, page = 1, limit = 50) {
      return request<{ items: Record<string, unknown>[]; total_count: number }>(
        `/community/posts/${postId}/comments?page=${page}&limit=${limit}`
      );
    },

    async createComment(postId: string, content: string, parentId?: string) {
      return request<Record<string, unknown>>(`/community/posts/${postId}/comments`, {
        method: 'POST',
        body: JSON.stringify({ content, parent_id: parentId ?? null }),
      });
    },

    async likeComment(postId: string, commentId: string) {
      return request<{ liked: boolean; like_count: number }>(
        `/community/posts/${postId}/comments/${commentId}/like`,
        { method: 'POST' }
      );
    },

    async deleteComment(postId: string, commentId: string) {
      return request(`/community/posts/${postId}/comments/${commentId}`, {
        method: 'DELETE',
      });
    },
  },


  // ── Storage ──
  storage: {
    async upload(file: File, folder = 'uploads') {
      const token = getAccessToken();
      const formData = new FormData();
      formData.append('file', file);
      formData.append('folder', folder);

      const res = await fetch(`${API_URL}/api/v1/storage/upload`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: formData,
      });

      if (!res.ok) throw new ApiError('Upload failed', res.status);
      return res.json() as Promise<{
        success: boolean;
        urls: Record<string, string>;
        file_id: string;
      }>;
    },

    async presignedUrl(filename: string, contentType: string, folder = 'uploads') {
      return request<{ upload_url: string; public_url: string }>('/api/v1/storage/presigned-url', {
        method: 'POST',
        body: JSON.stringify({ filename, content_type: contentType, folder }),
      });
    },
  },

  // ── AI ──
  ai: {
    async generate(prompt: string, taskType = 'GENERAL') {
      return request<{ response: string; model_used: string }>('/api/v1/ai/generate', {
        method: 'POST',
        body: JSON.stringify({ prompt, task_type: taskType }),
      });
    },

    async explain(prompt: string) {
      return request<{ response: string }>('/api/v1/ai/explain', {
        method: 'POST',
        body: JSON.stringify({ prompt, task_type: 'EDUCATIONAL_EXPLANATION' }),
      });
    },

    async lessonContent(courseTitle: string, lessonTitle: string, level = 'beginner') {
      return request<{ lesson_content: Record<string, unknown> }>('/api/v1/ai/lesson-content', {
        method: 'POST',
        body: JSON.stringify({ course_title: courseTitle, lesson_title: lessonTitle, level }),
      });
    },
  },

  // ── Resources ──
  resources: {
    async search(query: string, limit = 20) {
      return request<Record<string, unknown>[]>('/resources/search', {
        method: 'POST',
        body: JSON.stringify({ query, limit_per_provider: limit }),
      });
    },

    async trending(limit = 20) {
      return request<Record<string, unknown>[]>(`/resources/trending?limit=${limit}`);
    },
  },

  // ── Notifications ──
  notifications: {
    async list(page = 1, perPage = 20, type?: string) {
      const params = new URLSearchParams({ page: String(page), per_page: String(perPage) });
      if (type) params.set('type', type);
      return request<{ notifications: Record<string, unknown>[]; total: number; unread_count: number }>(`/notifications?${params}`);
    },
    async markRead(notificationId: string) {
      return request(`/notifications/${notificationId}/read`, { method: 'POST' });
    },
    async markAllRead() {
      return request('/notifications/read-all', { method: 'POST' });
    },
    async unreadCount() {
      return request<{ count: number }>('/notifications/unread-count');
    },
  },

  // ── Discover ──
  discover: {
    async places(page = 1, perPage = 20, category?: string) {
      const params = new URLSearchParams({ page: String(page), per_page: String(perPage) });
      if (category) params.set('category', category);
      return request<{ places: Record<string, unknown>[]; total: number }>(`/discover/places?${params}`);
    },

    async place(placeId: string) {
      return request<Record<string, unknown>>(`/discover/places/${placeId}`);
    },

    async trending() {
      return request<{ topics: Record<string, unknown>[]; resources: Record<string, unknown>[] }>('/discover/trending');
    },
  },

  // ── Generic helpers ──
  get: <T>(endpoint: string) => request<T>(endpoint),
  post: <T>(endpoint: string, data?: unknown) =>
    request<T>(endpoint, { method: 'POST', body: data ? JSON.stringify(data) : undefined }),
  put: <T>(endpoint: string, data?: unknown) =>
    request<T>(endpoint, { method: 'PUT', body: data ? JSON.stringify(data) : undefined }),
  delete: <T>(endpoint: string) => request<T>(endpoint, { method: 'DELETE' }),
};
