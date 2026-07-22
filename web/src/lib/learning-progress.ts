import { ApiError, clearTokens, getAccessToken } from '@/lib/api';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoai.app';

export interface LessonCompletionResponse {
  id: string;
  lesson_id: string | number;
  completed_at: string;
  score?: number | null;
  xp_awarded: number;
}

export interface CourseProgressResponse {
  course_id: string | number;
  user_id: string | number;
  total_lessons: number;
  completed_lessons: number;
  progress_percent: number;
  current_lesson_id?: string | number | null;
  last_accessed_at?: string | null;
  estimated_time_remaining?: number | null;
}

async function learningRequest<T>(endpoint: string, init?: RequestInit): Promise<T> {
  const token = getAccessToken();
  if (!token) {
    throw new ApiError('Sign in to save lesson progress.', 401);
  }

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init?.headers ?? {}),
    },
  });

  if (response.status === 401) {
    clearTokens();
    throw new ApiError('Your session expired. Sign in again to save progress.', 401);
  }

  if (!response.ok) {
    const body = await response.json().catch(() => ({ detail: 'Unable to save learning progress.' }));
    throw new ApiError(
      body.detail || body.message || 'Unable to save learning progress.',
      response.status,
    );
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

export async function markLessonComplete(
  lessonId: string,
  score?: number,
): Promise<LessonCompletionResponse> {
  return learningRequest<LessonCompletionResponse>('/learning/completions', {
    method: 'POST',
    body: JSON.stringify({
      lesson_id: lessonId,
      ...(typeof score === 'number' ? { score } : {}),
    }),
  });
}

export async function getCourseProgress(courseId: string): Promise<CourseProgressResponse> {
  return learningRequest<CourseProgressResponse>(
    `/learning/users/me/courses/${encodeURIComponent(courseId)}/progress`,
  );
}

export function normalizeProgressPercent(value: number): number {
  const normalized = value > 1 ? value : value * 100;
  return Math.max(0, Math.min(Math.round(normalized), 100));
}
