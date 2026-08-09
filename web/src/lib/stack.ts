import { ApiError, api, clearTokens, getAccessToken } from '@/lib/api';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.lyoai.app';

// Web's own production origin — the domain a stack item's share link
// points to. Not recorded anywhere in either repo (no NEXT_PUBLIC_SITE_URL,
// confirmed by checking layout.tsx/.env.example), so this follows the same
// https://lyoai.app convention Android's StackRepository.kt already
// assumed, by the same reasoning: api.lyoai.app is the verified API host,
// so lyoai.app is the assumed web host. Single named constant — trivial to
// correct if wrong.
const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://lyoai.app';

// ── Wire types (match lyo_app/stack/routes.py's inline Pydantic schemas
//    exactly — NOT lyo_app/stack/schemas.py, which is a differently-shaped,
//    unused-by-these-routes StackItemCreate/StackItemRead) ──────────────────

export type StackItemType =
  | 'topic'
  | 'course'
  | 'skill'
  | 'question'
  | 'event'
  | 'video'
  | 'article'
  | 'session';

export type StackItemStatus = 'not_started' | 'in_progress' | 'completed' | 'paused';

export interface StackItem {
  id: number;
  user_id: number;
  title: string;
  description?: string | null;
  item_type: StackItemType;
  status: StackItemStatus;
  progress: number; // 0.0–1.0
  priority: number;
  content_id?: string | null;
  content_type?: string | null;
  extra_data?: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
  started_at?: string | null;
  completed_at?: string | null;
}

interface StackItemListResponse {
  items: StackItem[];
  total: number;
  limit: number;
  offset: number;
}

const ITEM_TYPE_COURSE: StackItemType = 'course';

async function stackRequest<T>(endpoint: string, init?: RequestInit): Promise<T> {
  const token = getAccessToken();
  if (!token) {
    throw new ApiError('Sign in to save this to your Stacks.', 401);
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
    throw new ApiError('Your session expired. Sign in again to sync your Stacks.', 401);
  }

  if (!response.ok) {
    const body = await response.json().catch(() => ({ detail: 'Unable to reach your Stacks.' }));
    throw new ApiError(body.detail || body.message || 'Unable to reach your Stacks.', response.status);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

/** The backend has no upsert-by-course semantics (`POST /items` always
 *  inserts a new row — confirmed by reading lyo_app/stack/crud.py
 *  directly, not assumed), so "does a stack item already exist for this
 *  course" is answered here with a client-side filter on `content_id`,
 *  mirroring Android's StackRepository.kt exactly. */
async function findCourseStackItem(courseId: string): Promise<StackItem | null> {
  const params = new URLSearchParams({ item_type: ITEM_TYPE_COURSE, limit: '100' });
  const res = await stackRequest<StackItemListResponse>(`/api/v1/stack/items?${params}`);
  return res.items.find((item) => item.content_id === courseId) ?? null;
}

/** Called the moment a learner enters a course's classroom (both the
 *  chat-proposal path and the catalog-detail path route through
 *  /classroom, so this one call covers both). Creates the Stack entry on
 *  first visit; returns the existing one unchanged on a repeat visit — a
 *  resumed course must not spawn a duplicate stack card. Never throws —
 *  a failed sync must not block learning. */
export async function upsertCourseOnStart(courseId: string, title: string): Promise<StackItem | null> {
  if (!courseId.trim()) return null;
  try {
    const existing = await findCourseStackItem(courseId);
    if (existing) return existing;
    return await stackRequest<StackItem>('/api/v1/stack/items', {
      method: 'POST',
      body: JSON.stringify({
        title: title.trim() || 'Course',
        item_type: ITEM_TYPE_COURSE,
        content_id: courseId,
        content_type: ITEM_TYPE_COURSE,
      }),
    });
  } catch {
    return null;
  }
}

/** `progress` is a 0.0–1.0 fraction. `status` is auto-derived server-side
 *  from `progress` (see the backend's PUT /items/{id} handler) — this
 *  never needs to send status itself. No-ops if the course has no stack
 *  entry yet rather than creating one, matching Android's behavior. */
export async function updateCourseProgress(courseId: string, progress: number): Promise<StackItem | null> {
  if (!courseId.trim()) return null;
  try {
    const existing = await findCourseStackItem(courseId);
    if (!existing) return null;
    return await stackRequest<StackItem>(`/api/v1/stack/items/${existing.id}`, {
      method: 'PUT',
      body: JSON.stringify({ progress: Math.max(0, Math.min(progress, 1)) }),
    });
  } catch {
    return null;
  }
}

/** The Home page's "Your Stacks" section — every saved course, most-
 *  recently-touched first. The backend sorts by `priority, created_at`
 *  (see routes.py/crud.py), NOT `updated_at`, so recency ordering is
 *  re-applied here client-side, matching Android's listCourseStacks. */
export async function listCourseStacks(): Promise<StackItem[]> {
  try {
    const params = new URLSearchParams({ item_type: ITEM_TYPE_COURSE, limit: '50' });
    const res = await stackRequest<StackItemListResponse>(`/api/v1/stack/items?${params}`);
    return [...res.items].sort(
      (a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime(),
    );
  } catch {
    return [];
  }
}

/** Posts a stack card in-app, to the real Community feed (distinct from
 *  the external Web Share API sheet the UI also offers — one shares
 *  outside the app via any installed app/browser, this shares inside it
 *  as a real, visible-to-others Community post). Uses the same
 *  content_id-derived link as the external share, so a course shared
 *  either way resolves to the same course. Returns whether the post was
 *  actually created, so the caller can surface a toast/error — mirrors
 *  Android's StackRepository.postCourseToCommunity. */
export async function postCourseToCommunity(
  courseId: string,
  title: string,
  progressPercent: number,
): Promise<boolean> {
  const shareUrl = courseShareUrl(courseId);
  const content = progressPercent > 0
    ? `I'm ${progressPercent}% through "${title}" on Lyo — join me: ${shareUrl}`
    : `Just started "${title}" on Lyo — check it out: ${shareUrl}`;
  try {
    await api.community.createPost({ content, tags: ['course'], post_type: 'text' });
    return true;
  } catch {
    return false;
  }
}

/** The canonical, cross-platform course link every share path builds — a
 *  real HTTPS link to this app's own /courses/{id} route, which resolves
 *  for any recipient whether or not they're signed in, matching Android's
 *  courseShareUrl exactly (not iOS's app-only lyoapp://course/{id}
 *  scheme). */
export function courseShareUrl(courseId: string): string {
  return `${SITE_URL}/courses/${courseId}`;
}
