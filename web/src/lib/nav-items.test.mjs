import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CROSS_PLATFORM_LABELS,
  NAV,
  RAIL_STORAGE_KEY,
  SIDEBAR_ITEMS,
  isActiveHref,
  isRailShortcut,
  readCollapsed,
  writeCollapsed,
} from './nav-items.mjs';

// ─── The names ───────────────────────────────────────────────────────────────

test('home is Focus, as it is on every other surface', () => {
  assert.equal(NAV.focus.label, 'Focus');
  assert.equal(NAV.focus.href, '/');
});

test('the AI is Ask Lyo, not LYO Tutor', () => {
  assert.equal(NAV.askLyo.label, 'Ask Lyo');
  assert.equal(NAV.askLyo.href, '/chat');
});

test('Create opens a sheet rather than navigating', () => {
  assert.equal(NAV.create.action, 'create');
  assert.equal(NAV.create.href, undefined);
});

test('every sidebar item can be reached somehow', () => {
  for (const item of SIDEBAR_ITEMS) {
    assert.ok(item.href || item.action, `${item.key} has neither href nor action`);
    assert.ok(item.label.length > 0, `${item.key} has no label`);
  }
});

test('the sidebar leads with Focus and Ask Lyo', () => {
  assert.deepEqual(SIDEBAR_ITEMS.slice(0, 2).map((i) => i.key), ['focus', 'askLyo']);
});

test('the cross-platform names are the ones the tab bars carry', () => {
  assert.deepEqual(CROSS_PLATFORM_LABELS, {
    focus: 'Focus',
    discover: 'Discover',
    community: 'Community',
    create: 'Create',
  });
  // Each one must match the item it names.
  for (const [key, label] of Object.entries(CROSS_PLATFORM_LABELS)) {
    assert.equal(NAV[key].label, label, `${key} disagrees with its own nav item`);
  }
});

test('courses and test prep are not claimed to be cross-platform', () => {
  assert.equal(CROSS_PLATFORM_LABELS.courses, undefined);
  assert.equal(CROSS_PLATFORM_LABELS.testPrep, undefined);
});

// ─── Which item is lit ───────────────────────────────────────────────────────

test('Focus is active only on the root', () => {
  assert.equal(isActiveHref('/', '/'), true);
  assert.equal(isActiveHref('/', '/courses'), false);
});

test('a section is active on itself and on its children', () => {
  assert.equal(isActiveHref('/community', '/community'), true);
  assert.equal(isActiveHref('/community', '/community/events/42'), true);
});

test('a sibling route with the same prefix does not light the item', () => {
  // `startsWith` alone lit Community on /community-guidelines and Ask Lyo on
  // /chatrooms. The boundary has to be a path segment.
  assert.equal(isActiveHref('/community', '/community-guidelines'), false);
  assert.equal(isActiveHref('/chat', '/chatrooms'), false);
  assert.equal(isActiveHref('/test-prep', '/test-preparation'), false);
});

test('a missing href is never active', () => {
  assert.equal(isActiveHref(undefined, '/'), false);
});

// ─── Remembering the rail ────────────────────────────────────────────────────

function fakeStorage(initial) {
  const map = new Map(Object.entries(initial ?? {}));
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, v),
    read: (k) => map.get(k),
  };
}

test('a first visit opens the menu', () => {
  assert.equal(readCollapsed(fakeStorage()), false);
});

test('a closed rail is still closed on the next page', () => {
  const storage = fakeStorage();
  writeCollapsed(storage, true);
  assert.equal(storage.read(RAIL_STORAGE_KEY), 'true');
  assert.equal(readCollapsed(storage), true);
});

test('reopening is remembered too', () => {
  const storage = fakeStorage({ [RAIL_STORAGE_KEY]: 'true' });
  writeCollapsed(storage, false);
  assert.equal(readCollapsed(storage), false);
});

test('storage that throws leaves the menu open rather than breaking the page', () => {
  const hostile = {
    getItem() { throw new Error('private mode'); },
    setItem() { throw new Error('private mode'); },
  };
  assert.equal(readCollapsed(hostile), false);
  assert.equal(writeCollapsed(hostile, true), false);
  assert.equal(readCollapsed(null), false);
  assert.equal(writeCollapsed(undefined, true), false);
});

// ─── The shortcut ────────────────────────────────────────────────────────────

test('[ toggles the rail', () => {
  assert.equal(isRailShortcut({ key: '[', target: { tagName: 'BODY' } }), true);
});

test('typing a bracket into a field does not collapse the menu', () => {
  for (const tagName of ['INPUT', 'TEXTAREA', 'SELECT']) {
    assert.equal(isRailShortcut({ key: '[', target: { tagName } }), false, tagName);
  }
  assert.equal(
    isRailShortcut({ key: '[', target: { tagName: 'DIV', isContentEditable: true } }),
    false,
  );
});

test('a modified bracket belongs to the browser, not to us', () => {
  assert.equal(isRailShortcut({ key: '[', metaKey: true, target: { tagName: 'BODY' } }), false);
  assert.equal(isRailShortcut({ key: '[', ctrlKey: true, target: { tagName: 'BODY' } }), false);
});

test('any other key is ignored', () => {
  assert.equal(isRailShortcut({ key: ']', target: { tagName: 'BODY' } }), false);
  assert.equal(isRailShortcut(null), false);
});
