/** Invite links survive authentication; their tokens are URL-safe base64. */
const INVITE_PATH = /^\/community\/invite\/[A-Za-z0-9_-]{16,64}$/;

/**
 * Where to go after logging in or signing up. Only known in-app destinations
 * are allowed (Test Prep, Community, or an event invite link), never an
 * arbitrary URL.
 */
export function authReturnPath(search) {
  const next = new URLSearchParams(search).get('next');
  if (next === '/test-prep' || next === '/community') return next;
  if (next && INVITE_PATH.test(next)) return next;
  return '/';
}

/** The login/signup switch link, keeping the same destination. */
export function authSwitchHref(page, search) {
  const next = authReturnPath(search);
  return next === '/' ? page : `${page}?next=${encodeURIComponent(next)}`;
}
