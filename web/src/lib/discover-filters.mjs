/** Pure Discover filter state; URLs remain shareable and browser-back friendly. */

/** @param {string|null|undefined} value
 * @returns {'for_you'|'latest'|'popular'|'saved'} */
export function normalizeDiscoverFeed(value) {
  return ['latest', 'popular', 'saved'].includes(value) ? value : 'for_you';
}

/**
 * @param {string} search
 * @param {'for_you'|'latest'|'popular'|'saved'} mode
 * @param {string} subject
 */
export function discoverFilterHref(search, mode, subject = '') {
  const params = new URLSearchParams(search);
  for (const key of ['clip', 'subject', 'feed', 'compose', 'topic']) params.delete(key);
  if (subject) params.set('subject', subject);
  else if (mode !== 'for_you') params.set('feed', mode);
  const suffix = params.toString();
  return '/discover' + (suffix ? '?' + suffix : '');
}

/** @param {string} value */
function allowedSubject(value) {
  const name = value?.trim();
  return name && !['general', 'unknown'].includes(name.toLowerCase());
}

/**
 * @param {Array<{name: string, count: number}>} published
 * @param {Array<Record<string,unknown>>} clips
 * @param {string} selected
 * @returns {string[]}
 */
export function discoverSubjects(published = [], clips = [], selected = '') {
  const names = new Map();
  const add = (raw) => {
    const name = String(raw || '').trim();
    if (allowedSubject(name) && !names.has(name.toLowerCase())) {
      names.set(name.toLowerCase(), name);
    }
  };
  for (const item of published) add(item.name);
  for (const clip of clips) {
    const meta = clip.metadata || {};
    add(clip.subject || meta.subject);
  }
  add(selected);
  return [...names.values()];
}
