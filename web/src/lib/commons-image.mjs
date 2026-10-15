/**
 * Wikimedia Commons image lookup, shared by the Classroom board and Chat.
 *
 * Commons is free, keyless and CORS-open, so this runs in the browser with no
 * backend involved and no credential to leak. It lived inside the Classroom
 * store; Chat needs the same lookup, and two copies of a search query are two
 * things to keep in step, so it lives here and both import it.
 *
 * The URL that comes back is checked against the same host allowlist the rest
 * of the app applies to teaching media — a search result is third-party input,
 * and `upload.wikimedia.org` is where Commons actually serves files from.
 */

/** Where Commons serves file bytes. Mirrors TEACHING_IMAGE_HOSTS. */
const COMMONS_FILE_HOST = 'upload.wikimedia.org';
/** Where a human-readable credit page lives. Mirrors TEACHING_SOURCE_HOSTS. */
const COMMONS_PAGE_HOST = 'commons.wikimedia.org';

/** The search request for a topic. Separated out so it can be asserted. */
export function commonsSearchUrl(query) {
  const params = new URLSearchParams({
    action: 'query',
    generator: 'search',
    gsrsearch: `filetype:bitmap ${String(query || '').trim()}`,
    gsrlimit: '1',
    gsrnamespace: '6',
    prop: 'imageinfo|info',
    inprop: 'url',
    iiprop: 'url|extmetadata',
    iiurlwidth: '760',
    format: 'json',
    origin: '*',
  });
  return `https://${COMMONS_PAGE_HOST}/w/api.php?${params}`;
}

/** An https URL served by `host` exactly, with no credentials and a real path. */
function approvedUrl(raw, host) {
  if (typeof raw !== 'string' || !raw || raw.length > 1200) return null;
  try {
    const url = new URL(raw);
    if (url.protocol !== 'https:') return null;
    if (url.hostname !== host) return null;
    if (url.username || url.password) return null;
    if (url.pathname === '/') return null;
    return raw;
  } catch {
    return null;
  }
}

/**
 * The usable image in a Commons API response, or null.
 *
 * Returns null rather than an unchecked URL whenever the shape is unfamiliar
 * or the host is not Commons' own file host.
 */
export function parseCommonsResponse(data) {
  const pages = data?.query?.pages;
  if (!pages || typeof pages !== 'object') return null;

  const first = Object.values(pages)[0];
  const info = first?.imageinfo?.[0];
  const url = approvedUrl(info?.thumburl, COMMONS_FILE_HOST)
    ?? approvedUrl(info?.url, COMMONS_FILE_HOST);
  if (!url) return null;

  return {
    url,
    attribution: typeof first?.title === 'string' && first.title
      ? first.title.replace(/^File:/, '')
      : 'Wikimedia Commons',
    sourceUrl: approvedUrl(first?.canonicalurl, COMMONS_PAGE_HOST) ?? undefined,
  };
}

/**
 * Look up one illustrative image for a topic.
 *
 * Never throws and never rejects: an image is a nicety, so a failed lookup is
 * silence rather than an error in the learner's way.
 *
 * @param {string} query
 * @param {(url: string) => Promise<Response>} [fetchImpl] injectable for tests
 */
export async function resolveCommonsImage(query, fetchImpl) {
  const topic = String(query || '').trim();
  if (!topic) return null;

  const doFetch = fetchImpl
    ?? (typeof fetch === 'function' ? (url) => fetch(url) : null);
  if (!doFetch) return null;

  try {
    const res = await doFetch(commonsSearchUrl(topic));
    if (!res || !res.ok) return null;
    return parseCommonsResponse(await res.json());
  } catch {
    return null;
  }
}
