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
const dom = new JSDOM('<!doctype html><body></body>', { url: 'http://localhost/chat' });
Object.assign(globalThis, { window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, SVGElement: dom.window.SVGElement,
  Element: dom.window.Element, IS_REACT_ACT_ENVIRONMENT: true });
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');
let pathname = '/chat';
const mocks = {
  'next/navigation': { usePathname: () => pathname },
  'next/link': { default: ({ children, ...props }) => React.createElement('a', props, children) },
  'next/image': { default: ({ priority, ...props }) => React.createElement('img', props) },
  '@/stores/auth-store': { useAuthStore: () => ({ user: null }) },
  '@/components/chat/MascotAvatar': { default: () => React.createElement('span', { 'data-mascot': true }) },
  '@/components/create/CreateSheet': { default: ({ isOpen }) => isOpen ? React.createElement('div', { role: 'dialog' }, 'Create') : null },
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
async function mount(t, route = '/chat', communityEnabled = false, discoverEnabled = true) {
  pathname = route;
  // These are build-time flags: load each configuration as a fresh module.
  mocks['@/lib/launch-features'] = {
    COMMUNITY_LAUNCH_ENABLED: communityEnabled,
    DISCOVER_LAUNCH_ENABLED: discoverEnabled,
  };
  modules.clear();
  const { Sidebar } = load(path.join(webRoot, 'src/components/layout/Sidebar.tsx'));
  const { MobileNav } = load(path.join(webRoot, 'src/components/layout/MobileNav.tsx'));
  window.localStorage.clear();
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  const render = async (route = pathname) => {
    pathname = route;
    await act(async () => root.render(React.createElement(React.Fragment, null,
      React.createElement(Sidebar), React.createElement(MobileNav))));
  };
  t.after(async () => { await act(async () => root.unmount()); container.remove(); });
  await render();
  return { container, render };
}

test('both real navigation components preserve the Community launch gate', async t => {
  const view = await mount(t);
  assert.equal(view.container.querySelectorAll('a[href="/community"]').length, 0);
  assert.equal(view.container.querySelectorAll('a[href="/discover"]').length, 2);
  assert.ok([...view.container.querySelectorAll('a')].some(a => a.textContent === 'Focus'));
  const enabled = await mount(t, '/chat', true);
  assert.equal(enabled.container.querySelectorAll('a[href="/community"]').length, 2);
});

// Hiding Community left its slot on the right of the mascot empty, so the
// phone bar carried Focus and Discover bunched on the left and nothing but
// Create on the right. Discover fills that slot while Community is held back,
// and steps back to the left when it ships — so this asserts both states, not
// just the one we launch with.
test('Discover holds Community\'s slot on the phone bar while Community is hidden', async t => {
  const groups = container => {
    const bar = container.querySelector('nav[aria-label="Mobile navigation"]');
    const [left, right] = [...bar.firstElementChild.children].filter(el => el.tagName === 'DIV');
    const hrefs = group => [...group.querySelectorAll('a')].map(a => a.getAttribute('href'));
    return { left: hrefs(left), right: hrefs(right), createOnRight: right.querySelector('button[aria-label="Create"]') };
  };

  const hidden = groups((await mount(t)).container);
  assert.deepEqual(hidden.left, ['/'], 'Focus keeps the left on its own');
  assert.deepEqual(hidden.right, ['/discover'], 'Discover sits where Community would');
  assert.ok(hidden.createOnRight, 'Create stays on the right beside it');

  const shipped = groups((await mount(t, '/chat', true)).container);
  assert.deepEqual(shipped.left, ['/', '/discover'], 'Discover returns to the left');
  assert.deepEqual(shipped.right, ['/community'], 'Community takes its slot back');
});

// Discover has its own launch gate: until its videos are proven to play, no
// nav may lead to it. Both bars drop it, and the phone bar keeps Focus on the
// left and Create on the right rather than leaving a hole.
test('both navs leave Discover out while its launch flag is off', async t => {
  const contained = await mount(t, '/chat', false, false);
  assert.equal(contained.container.querySelectorAll('a[href="/discover"]').length, 0);
  assert.equal(contained.container.querySelectorAll('a[href="/community"]').length, 0);
  const bar = contained.container.querySelector('nav[aria-label="Mobile navigation"]');
  const [left, right] = [...bar.firstElementChild.children].filter(el => el.tagName === 'DIV');
  assert.deepEqual([...left.querySelectorAll('a')].map(a => a.getAttribute('href')), ['/']);
  assert.deepEqual([...right.querySelectorAll('a')].map(a => a.getAttribute('href')), []);
  assert.ok(right.querySelector('button[aria-label="Create"]'), 'Create stays on the right');

  const withCommunity = await mount(t, '/chat', true, false);
  assert.equal(withCommunity.container.querySelectorAll('a[href="/discover"]').length, 0);
  assert.equal(withCommunity.container.querySelectorAll('a[href="/community"]').length, 2);
});

test('entering Classroom removes both navs and releases the rail keyboard shortcut', async t => {
  const view = await mount(t);
  assert.ok(view.container.querySelector('aside'));
  for (const route of ['/classroom', '/classroom/session-42']) {
    await view.render(route);
    assert.equal(view.container.textContent, '');
    const key = new window.KeyboardEvent('keydown', { key: '[', bubbles: true, cancelable: true });
    await act(async () => window.dispatchEvent(key));
    assert.equal(key.defaultPrevented, false);
    assert.equal(window.localStorage.getItem('lyo_sidebar_collapsed'), null);
  }
  await view.render('/classroom-guide');
  assert.ok(view.container.querySelector('aside'), 'a sibling route is not an active lesson');
});

test('desktop and phone Create buttons still open their creation sheets', async t => {
  const view = await mount(t);
  const buttons = [...view.container.querySelectorAll('button')]
    .filter(button => button.textContent.trim() === 'Create' || button.getAttribute('aria-label') === 'Create');
  assert.equal(buttons.length, 2);
  for (const [index, button] of buttons.entries()) {
    await act(async () => button.click());
    assert.equal(view.container.querySelectorAll('[role="dialog"]').length, index + 1);
  }
});
