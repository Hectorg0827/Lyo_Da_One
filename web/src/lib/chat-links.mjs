/**
 * How a link inside a chat message is resolved.
 *
 * Chat text is model-produced and the server also writes links into it — the
 * Test Prep handoff says "Open [Test Prep](https://lyoai.app/test-prep)". Two
 * things follow from that, and this module exists for both.
 *
 * **An app link must stay in the app.** Written as an absolute URL on the
 * product's own domain, a plain anchor is a full page load: the learner leaves
 * the running React app, loses the open conversation, and waits for a cold
 * start — to reach a route the client router could have opened instantly. So a
 * link to our own origin is recognised and handed back as an internal path.
 *
 * **A model-produced href is untrusted input.** `javascript:` and `data:` URLs
 * in an anchor are script execution on click, and the text these appear in is
 * generated. Only http, https and mailto survive; everything else is dropped
 * rather than sanitised into something that might still run.
 *
 * `.mjs` so the Node test runner can import it directly, matching the other
 * shared contracts in this folder.
 */

/** Hosts that are this product, and whose links belong in the router. */
export const APP_HOSTS = Object.freeze([
  'lyoai.app',
  'www.lyoai.app',
  'localhost',
]);

/** Schemes an anchor may carry. Anything else is not a link we will render. */
const SAFE_SCHEMES = Object.freeze(['http:', 'https:', 'mailto:']);

/**
 * Classify one href.
 *
 * Returns `{ kind: 'internal', href }` for a route this app serves,
 * `{ kind: 'external', href }` for a safe link elsewhere, and
 * `{ kind: 'unsafe' }` for anything that must not become an anchor at all.
 */
export function classifyChatLink(href) {
  const raw = (href ?? '').toString().trim();
  if (!raw) return { kind: 'unsafe' };

  // A bare fragment or query stays on the current page.
  if (raw.startsWith('#') || raw.startsWith('?')) return { kind: 'internal', href: raw };

  // A root-relative path is already an app route.
  if (raw.startsWith('/')) {
    // `//evil.com` is protocol-relative — an external URL wearing a path's
    // clothes, and the one case where "starts with a slash" is not a route.
    if (raw.startsWith('//')) return { kind: 'unsafe' };
    return { kind: 'internal', href: raw };
  }

  let url;
  try {
    url = new URL(raw);
  } catch {
    // Not parseable as absolute and not path-shaped: treat as text, not a link.
    return { kind: 'unsafe' };
  }

  if (!SAFE_SCHEMES.includes(url.protocol)) return { kind: 'unsafe' };

  if (url.protocol !== 'mailto:' && APP_HOSTS.includes(url.hostname)) {
    // Keep the path, query and hash; drop the origin so the router handles it.
    return { kind: 'internal', href: `${url.pathname}${url.search}${url.hash}` || '/' };
  }

  return { kind: 'external', href: url.toString() };
}
