/**
 * What the product's places are called, in one place.
 *
 * The sidebar said "Home" and "LYO Tutor". iOS says Focus, Android says Focus,
 * and this site's own phone nav says Focus — so the desktop sidebar disagreed
 * with the phone nav on the same website, and a learner moving between them
 * met two names for one screen.
 *
 * Both web navs now read their labels from here, so the two cannot drift
 * apart again, and `scripts/verify-nav-naming-parity.mjs` reads the iOS and
 * Android sources to check this file still agrees with them.
 *
 * `Create` is not a route. It opens the same sheet on every surface, so it
 * carries `action` instead of `href` and the components branch on that.
 */

export const NAV = {
  focus: { key: 'focus', href: '/', label: 'Focus' },
  askLyo: { key: 'askLyo', href: '/chat', label: 'Ask Lyo' },
  courses: { key: 'courses', href: '/courses', label: 'My Courses' },
  testPrep: { key: 'testPrep', href: '/test-prep', label: 'Test Prep' },
  community: { key: 'community', href: '/community', label: 'Community' },
  discover: { key: 'discover', href: '/discover', label: 'Discover' },
  create: { key: 'create', action: 'create', label: 'Create' },
  profile: { key: 'profile', href: '/profile', label: 'Profile' },
};

/** The sidebar, top to bottom. Profile is not here: it is the footer row. */
export const SIDEBAR_ITEMS = [
  NAV.focus,
  NAV.askLyo,
  NAV.courses,
  NAV.testPrep,
  NAV.community,
  NAV.discover,
  NAV.create,
];

/**
 * The names that must read the same on iOS, Android and the web.
 *
 * Courses and Test Prep are deliberately absent: a sidebar holds eight items
 * where a five-slot tab bar cannot, so they are web-only by capacity, not by
 * accident. `askLyo` is absent too — mobile reaches it by tapping the mascot
 * rather than by a label.
 */
export const CROSS_PLATFORM_LABELS = {
  focus: 'Focus',
  discover: 'Discover',
  community: 'Community',
  create: 'Create',
};

/**
 * Is this nav item the page we are on?
 *
 * A prefix test alone marks `/community` active on `/community-guidelines`,
 * and `/chat` active on `/chatrooms`: the boundary has to be a path segment,
 * not just a matching string.
 */
export function isActiveHref(href, pathname) {
  if (typeof href !== 'string' || typeof pathname !== 'string') return false;
  if (href === '/') return pathname === '/';
  return pathname === href || pathname.startsWith(`${href}/`);
}

// ─── Remembering whether the rail is closed ──────────────────────────────────

export const RAIL_STORAGE_KEY = 'lyo_sidebar_collapsed';

/**
 * The rail's remembered state.
 *
 * It already collapsed, but reopened itself on every page load, which is what
 * made it feel like it did not work. Storage throws in a private window and
 * returns nothing on a first visit, and neither is a reason to fail to render
 * a sidebar: both mean "open".
 */
export function readCollapsed(storage) {
  try {
    return storage?.getItem(RAIL_STORAGE_KEY) === 'true';
  } catch {
    return false;
  }
}

export function writeCollapsed(storage, collapsed) {
  // Not optional chaining: `storage?.setItem(…)` on a null storage is a no-op
  // that returns undefined, so this reported a save it had not made.
  if (!storage) return false;
  try {
    storage.setItem(RAIL_STORAGE_KEY, collapsed ? 'true' : 'false');
    return true;
  } catch {
    // A preference that cannot be saved is not worth breaking the page over.
    return false;
  }
}

/**
 * Should this keystroke toggle the rail?
 *
 * `[` is the shortcut, but not while the learner is typing: the chat
 * composer, the search box and every form on the site would otherwise eat a
 * bracket and collapse the menu instead.
 */
export function isRailShortcut(event) {
  if (!event || event.key !== '[') return false;
  if (event.metaKey || event.ctrlKey || event.altKey) return false;
  const target = event.target;
  const tag = typeof target?.tagName === 'string' ? target.tagName.toUpperCase() : '';
  if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return false;
  return !target?.isContentEditable;
}
