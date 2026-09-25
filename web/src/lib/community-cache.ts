import type { NearbyLearningResponse } from '@/types';

/**
 * A disposable performance cache for map results — never the source of
 * truth. It lets a returning visit paint instantly (then revalidate) and lets
 * a failed request fall back to the last good answer with an honest "from N
 * minutes ago" label. Saves, RSVPs and created events always come from the
 * server; this cache only stores what the server last said about an area.
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
  latitude: number;
  longitude: number;
  radiusKm: number;
  filters: string;
  query: string;
}): string {
  return [
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
