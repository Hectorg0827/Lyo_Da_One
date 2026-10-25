/**
 * Community while signed out, against the real page component.
 *
 * Every Community call needs an account, the map's own `/nearby` included, and
 * `request()` treats a 401 on a required call as a dead session: it clears the
 * tokens and sets `window.location` to `/auth/login`. So a signed-out visitor
 * was asked for their device location, had their requests refused, and was then
 * sent to a login page that had lost the fact they were heading for Community.
 *
 * These mount the page in all three sign-in states, because the interesting
 * defects are on the edges: a prompt shown while the session is still being
 * read would flash at every signed-in learner on a hard reload, and a gate that
 * holds after sign-in would leave the map permanently blank.
 */
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import Module, { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { JSDOM } from 'jsdom';

const webRoot = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const dom = new JSDOM('<!doctype html><body></body>', { url: 'http://localhost/community' });
Object.assign(globalThis, {
  window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, SVGElement: dom.window.SVGElement,
  Element: dom.window.Element, IS_REACT_ACT_ENVIRONMENT: true,
});
dom.window.matchMedia = query => ({
  matches: false, media: query, onchange: null,
  addEventListener() {}, removeEventListener() {}, addListener() {}, removeListener() {},
  dispatchEvent() { return false; },
});
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');

/** Every Community call the page makes, in order, so silence is assertable. */
let calls = [];
let locationAsked = 0;
dom.window.navigator.geolocation = {
  // The position has to actually arrive: `ready` gates every data request, so
  // a location that never resolves leaves the signed-in path asserting only
  // that the page opened, and the fetches it is supposed to prove untested.
  getCurrentPosition(onSuccess) {
    locationAsked += 1;
    onSuccess({ coords: { latitude: 40.713, longitude: -74.006 } });
  },
  watchPosition(onSuccess) {
    locationAsked += 1;
    onSuccess({ coords: { latitude: 40.713, longitude: -74.006 } });
    return 0;
  },
  clearWatch() {},
};
// The page reads the bare global `navigator`, and Node supplies one of its own
// with no `geolocation` on it — so without this the location branch is skipped
// and a test asserting it would pass for the wrong reason.
Object.defineProperty(globalThis, 'navigator', {
  value: dom.window.navigator, configurable: true, writable: true,
});

// A call records itself and then hangs: resolving it would start the page's
// follow-up work, and what is under test is whether the call happens at all.
const community = new Proxy({}, {
  get: (_target, name) => (...args) => {
    calls.push(String(name));
    return new Promise(() => {});
  },
});
const api = { community };

let auth = { isAuthenticated: false, isLoading: false };
const mocks = {
  '@/lib/api': { api, ApiError: class ApiError extends Error {} },
  '@/stores/auth-store': { useAuthStore: () => auth },
  'next/link': { default: ({ children, ...props }) => React.createElement('a', props, children) },
  'next/navigation': { useRouter: () => ({ push() {}, replace() {} }), useSearchParams: () => new URLSearchParams() },
  '@/hooks/use-sync': { useSyncEvents: () => {} },
  // Leaflet draws to a real canvas and is not the subject here.
  '@/components/community/CommunityEventMap': {
    default: () => React.createElement('div', { 'data-map': true }),
    markerColors: {},
  },
};

const modules = new Map();
function load(filename) {
  if (modules.has(filename)) return modules.get(filename).exports;
  const mod = new Module(filename);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(webRoot);
  modules.set(filename, mod);
  mod.require = name => {
    if (mocks[name]) return mocks[name];
    if (name.startsWith('@/') || name.startsWith('./')) {
      const base = name.startsWith('@/') ? path.join(webRoot, 'src', name.slice(2))
        : path.resolve(path.dirname(filename), name);
      if (base.endsWith('.mjs')) return require(base);
      const file = ['.tsx', '.ts'].map(ext => base + ext).find(existsSync);
      if (file) return load(file);
    }
    return require(name);
  };
  mod._compile(ts.transpileModule(readFileSync(filename, 'utf8'), { compilerOptions: {
    jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, filename);
  return mod.exports;
}

async function mount(t, authState) {
  auth = authState;
  calls = [];
  locationAsked = 0;
  modules.clear();
  const Page = load(path.join(webRoot, 'src/app/(main)/community/page.tsx')).default;
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  t.after(async () => { await act(async () => root.unmount()); container.remove(); });
  await act(async () => root.render(React.createElement(Page)));
  return container;
}

test('signed out, Community asks for sign-in and keeps itself as the destination', async t => {
  const container = await mount(t, { isAuthenticated: false, isLoading: false });

  const links = [...container.querySelectorAll('a')].map(a => a.getAttribute('href'));
  assert.ok(links.includes('/auth/login?next=%2Fcommunity'), `sign-in link missing, got ${JSON.stringify(links)}`);
  assert.ok(links.includes('/auth/signup?next=%2Fcommunity'), `sign-up link missing, got ${JSON.stringify(links)}`);
  // `authReturnPath` only honours an allow-listed `next`, so a link it would
  // discard is the same dead end in a new costume.
  const { authReturnPath } = require(path.join(webRoot, 'src/lib/auth-return.mjs'));
  assert.equal(authReturnPath('?next=%2Fcommunity'), '/community');
});

test('signed out, nothing is requested and no location is asked for', async t => {
  await mount(t, { isAuthenticated: false, isLoading: false });
  assert.deepEqual(calls, [], 'a visitor who cannot be served should cost no requests');
  assert.equal(locationAsked, 0, 'asking for GPS before sign-in prompts for a map nobody can see');
});

test('while the session is still being read, neither the prompt nor the requests appear', async t => {
  const container = await mount(t, { isAuthenticated: false, isLoading: true });
  // isLoading starts true on every load, so a prompt here is one every
  // signed-in learner sees flash before their session resolves.
  assert.equal(
    [...container.querySelectorAll('a')].filter(a => (a.getAttribute('href') || '').startsWith('/auth/')).length,
    0,
    'the prompt must wait until the session is known',
  );
  // Nor the map: its controls act as soon as they are on screen, and the
  // locate button and search box would both act for an unknown viewer.
  assert.equal(container.querySelector('[data-map]'), null, 'the map must not render for an unknown viewer');
  assert.deepEqual(calls, []);
});

test('signed in, posts load first and the map opens only when requested', async t => {
  const container = await mount(t, { isAuthenticated: true, isLoading: false, user: { id: 7 } });
  // Posts are now the Community landing view. It should not ask for location,
  // but it must actually fetch the signed-in feed, not merely log an opening.
  assert.ok(calls.includes('track'), `expected the open to be recorded, got ${JSON.stringify(calls)}`);
  assert.ok(calls.includes('posts'), `the Community post feed never loaded, got ${JSON.stringify(calls)}`);
  assert.equal(locationAsked, 0, 'opening posts must not ask for location');

  const mapTab = [...container.querySelectorAll('nav[aria-label="Community sections"] button')]
    .find(button => button.textContent === 'Around Me');
  assert.ok(mapTab, 'the signed-in Community map tab should be reachable');
  await act(async () => mapTab.dispatchEvent(new dom.window.MouseEvent('click', { bubbles: true })));
  assert.ok(calls.includes('nearby'), `the map never asked for anything, got ${JSON.stringify(calls)}`);
  assert.ok(calls.includes('me'), `account state was never read, got ${JSON.stringify(calls)}`);
  assert.equal(locationAsked, 1, 'a learner who opens the map is asked once for their location');
});

test('the map cache is keyed per account, so one learner cannot read another', async () => {
  // A logout leaves this cache in place, and sessionStorage outlives the reload
  // a session expiry causes, so the key is the only thing keeping the previous
  // learner's `is_saved`/`is_attending` marks away from the next one.
  modules.clear();
  const cache = load(path.join(webRoot, 'src/lib/community-cache.ts'));
  const where = { latitude: 40.713, longitude: -74.006, radiusKm: 15, filters: '', query: '' };
  const keyA = cache.nearbyCacheKey({ account: '7', ...where });
  const keyB = cache.nearbyCacheKey({ account: '8', ...where });
  assert.notEqual(keyA, keyB, 'two learners in the same place must not share one entry');

  cache.writeNearby(keyA, { nodes: [{ id: 'n1', is_saved: true }] });
  assert.ok(cache.readNearby(keyA), 'the learner who stored it still reads their own entry');
  assert.equal(cache.readNearby(keyB), null, 'the next learner must not inherit it');
});
