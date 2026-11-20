import type { NearbyLearningResponse } from '@/types';

/**
 * A disposable performance cache for map results — never the source of
 * truth. It lets a returning visit paint instantly (then revalidate) and lets
 * a failed request fall back to the last good answer with an honest "from N
 * minutes ago" label.
 *
 * What the server says about an area is partly about *who asked*: every node
 * carries `is_saved`, `is_joined` and `is_attending` for the viewer. So the
 * key starts with the account. Without that, one learner signing out and
 * another signing in on the same device inside `FRESH_MS` served the second
 * learner the first one's entry — fresh, so not revalidated — and showed them
 * someone else's saved and attending marks. A logout does not clear this, and
 * sessionStorage outlives the reload that a session expiry causes, so keying
 * it is what actually closes that off.
 */

const STORAGE_KEY = 'lyo.community.nearby.v1';
const MAX_ENTRIES = 12;
/** Younger than this: shown without revalidating. */
export const FRESH_MS = 60_000;
/** Older than this: never shown, even offline. */
const MAX_AGE_MS = 6 * 60 * 60 * 1000;

interface Entry {
  savedAt: number;
  response: NearbyLearningResponse;
}

const memory = new Map<string, Entry>();
let hydrated = false;

function storage(): Storage | null {
  try {
    return typeof window === 'undefined' ? null : window.sessionStorage;
  } catch {
    return null;
  }
}

function hydrate() {
  if (hydrated) return;
  hydrated = true;
  try {
    const raw = storage()?.getItem(STORAGE_KEY);
    if (!raw) return;
    const entries = JSON.parse(raw) as Array<[string, Entry]>;
    for (const [key, entry] of entries) {
      if (entry && Date.now() - entry.savedAt < MAX_AGE_MS) memory.set(key, entry);
    }
  } catch {
    // A corrupt cache is just an empty cache.
  }
}

function persist() {
  try {
    storage()?.setItem(STORAGE_KEY, JSON.stringify(Array.from(memory.entries()).slice(-MAX_ENTRIES)));
  } catch {
    // Quota or privacy mode: the in-memory cache still works for this tab.
  }
}

export function nearbyCacheKey(parts: {
  /** The viewer this answer was for; entries are never shared across accounts. */
  account: string;
  latitude: number;
  longitude: number;
  radiusKm: number;
  filters: string;
  query: string;
}): string {
  return [
    parts.account,
    parts.latitude.toFixed(3),
    parts.longitude.toFixed(3),
    parts.radiusKm.toFixed(1),
    parts.filters,
    parts.query.trim().toLowerCase(),
  ].join('|');
}

export function readNearby(key: string): Entry | null {
  hydrate();
  const entry = memory.get(key);
  if (!entry) return null;
  if (Date.now() - entry.savedAt > MAX_AGE_MS) {
    memory.delete(key);
    return null;
  }
  return entry;
}

export function writeNearby(key: string, response: NearbyLearningResponse) {
  hydrate();
  memory.delete(key);
  memory.set(key, { savedAt: Date.now(), response });
  while (memory.size > MAX_ENTRIES) {
    const oldest = memory.keys().next().value;
    if (oldest === undefined) break;
    memory.delete(oldest);
  }
  persist();
}

/** After a save/RSVP the cached copies are stale; drop them. */
export function invalidateNearby() {
  memory.clear();
  persist();
}
