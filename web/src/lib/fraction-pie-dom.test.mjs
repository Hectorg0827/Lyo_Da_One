import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import Module, { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { JSDOM } from 'jsdom';

const webRoot = fileURLToPath(new URL('../../', import.meta.url));
const require = createRequire(new URL('../../package.json', import.meta.url));
const ts = require('typescript');
const dom = new JSDOM('<!doctype html><body></body>', { url: 'http://localhost' });
Object.assign(globalThis, { window: dom.window, document: dom.window.document,
  HTMLElement: dom.window.HTMLElement, IS_REACT_ACT_ENVIRONMENT: true });
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');
const modules = new Map();
let state;
let classroomUpdates;
const useChatStore = selector => selector(state);
useChatStore.getState = () => state;
const mocks = {
  '@/stores/chat-store': { useChatStore },
  '@/stores/classroom-store': { useClassroomStore: selector => selector({
    languageCode: 'en', updateActivity: (id, values) => classroomUpdates.push({ id, values }),
  }) },
  './Explorable': { Explorable: () => null },
};

// Run the actual TSX renderers. Only stores and the unrelated graph component
// are replaced; SVG, React event handling, range controls and save logic are real.
function loadTsx(filename) {
  if (modules.has(filename)) return modules.get(filename).exports;
  const mod = new Module(filename);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(webRoot);
  modules.set(filename, mod);
  mod.require = name => {
    if (mocks[name]) return mocks[name];
    if (name.startsWith('@/')) {
      const base = path.join(webRoot, 'src', name.slice(2));
      if (base.endsWith('.mjs')) return require(base);
      const resolved = ['.tsx', '.ts'].map(ext => base + ext).find(existsSync);
      if (resolved) return loadTsx(resolved);
    }
    return require(name);
  };
  mod._compile(ts.transpileModule(readFileSync(filename, 'utf8'), { compilerOptions: {
    jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, filename);
  return mod.exports;
}

const { FractionPie } = loadTsx(path.join(webRoot, 'src/components/shared/FractionPie.tsx'));
const { TeachingVisualView, TeachingVisualCard } = loadTsx(path.join(webRoot, 'src/components/classroom/TeachingVisualView.tsx'));
const TeachingVisualBlock = loadTsx(path.join(webRoot, 'src/components/chat/blocks/TeachingVisualBlock.tsx')).default;
const fixture = JSON.parse(readFileSync(new URL('../../../Sources/Tests/Fixtures/SharedFractionPie.json', import.meta.url), 'utf8'));

async function mount(Component, props) {
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  await act(async () => root.render(React.createElement(Component, props)));
  return { container, root, close: async () => {
    await act(async () => root.unmount()); container.remove();
  } };
}

async function range(container, label, value) {
  const control = [...container.querySelectorAll('label')].find(x => x.textContent.startsWith(label));
  const input = document.getElementById(control.htmlFor);
  await act(async () => {
    Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set.call(input, String(value));
    input.dispatchEvent(new window.Event('input', { bubbles: true }));
    input.dispatchEvent(new window.Event('change', { bubbles: true }));
  });
}
const readout = container => container.querySelector('output')?.textContent;
async function tick(t, ms = 300) { await act(async () => { t.mock.timers.tick(ms); }); }
function chatState(save) {
  const message = { id: 'message-1', blocks: [fixture] };
  state = { activeConversationId: 'conversation-1', updateVisual: save,
    conversations: [{ id: 'conversation-1', messages: [message] }] };
  return { block: structuredClone(fixture), message };
}

test('real pie supports pointer, keyboard, sliders, zero, one whole and reset', async () => {
  const changes = [];
  const view = await mount(FractionPie, { initial: { parts: 4, value: 3 }, whole: 12, unit: 'apples', onChange: v => changes.push(v) });
  try {
    assert.match(readout(view.container), /^3\/4.*75%$/);
    assert.match(view.container.textContent, /9 apples/);
    await act(async () => view.container.querySelector('[aria-label="Slice 2 of 4"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true })));
    assert.equal(view.container.querySelector('[aria-label="Slice 2 of 4"]').getAttribute('aria-pressed'), 'false');
    assert.equal(view.container.querySelector('[aria-label="Slice 3 of 4"]').getAttribute('aria-pressed'), 'true');
    assert.deepEqual(changes.at(-1), { parts: 4, value: 2 });
    for (const key of ['Enter', ' ']) {
      await act(async () => view.container.querySelector('[aria-label="Slice 4 of 4"]').dispatchEvent(new window.KeyboardEvent('keydown', { key, bubbles: true })));
    }
    assert.match(readout(view.container), /^2\/4/);
    await range(view.container, 'Denominator', 8);
    assert.equal(view.container.querySelectorAll('path[role="button"]').length, 8);
    await range(view.container, 'Numerator', 0);
    assert.match(readout(view.container), /^0\/8.*0%$/);
    await range(view.container, 'Denominator', 1);
    await range(view.container, 'Numerator', 1);
    assert.match(readout(view.container), /^1\/1.*100%$/);
    await act(async () => [...view.container.querySelectorAll('button')].find(x => x.textContent === 'Reset').click());
    assert.deepEqual(changes.at(-1), { parts: 4, value: 3 });
  } finally { await view.close(); }
});

test('Classroom and Test Prep renderer routes atomic exploration to the activity, without grading', async () => {
  classroomUpdates = [];
  const view = await mount(TeachingVisualView, { id: 'visual:step-1', visual: fixture.content.visual });
  try {
    await range(view.container, 'Denominator', 2);
    assert.deepEqual(classroomUpdates, [{ id: 'visual:step-1', values: { parts: 2, value: 2 } }]);
    assert.match(readout(view.container), /^2\/2.*100%$/);
  } finally { await view.close(); }
});

test('all 230 supported numerator/denominator states render exact fractions and matching slice counts', async () => {
  for (let parts = 1; parts <= 20; parts++) for (let value = 0; value <= parts; value++) {
    const view = await mount(TeachingVisualCard, { id: `pie-${parts}-${value}`,
      visual: { ...fixture.content.visual, parts, value } });
    try {
      assert.ok(readout(view.container).startsWith(`${value}/${parts}=`));
      assert.equal(view.container.querySelectorAll('path[role="button"]').length, parts);
      assert.equal(view.container.querySelectorAll('path[aria-pressed="true"]').length, value);
      assert.doesNotMatch(view.container.textContent, /NaN|Infinity/);
    } finally { await view.close(); }
  }
});

test('Chat coalesces rapid edits, retains failed saves, and clears the error on retry', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const calls = [];
  let succeeds = false;
  const props = chatState(async (...args) => { calls.push(args); return succeeds; });
  const view = await mount(TeachingVisualBlock, props);
  try {
    await range(view.container, 'Numerator', 2);
    await range(view.container, 'Numerator', 1);
    await tick(t);
    assert.equal(calls.length, 1);
    assert.deepEqual(calls[0].at(-1), { parts: 4, value: 1 });
    assert.match(view.container.querySelector('[role="status"]').textContent, /Could not save/);
    succeeds = true;
    await act(async () => [...view.container.querySelectorAll('button')].find(x => x.textContent === 'Retry').click());
    assert.equal(calls.length, 2);
    assert.equal(view.container.querySelector('[role="status"]'), null);
  } finally { await view.close(); }
});

test('Chat keeps one save in flight across unmount/reopen, and saves the newest edit last', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const calls = [], releases = [];
  const props = chatState((...args) => { calls.push(args); return new Promise(resolve => releases.push(resolve)); });
  let view = await mount(TeachingVisualBlock, props);
  try {
    await range(view.container, 'Numerator', 1);
    await tick(t);
    assert.equal(calls.length, 1);
    await view.close();
    view = await mount(TeachingVisualBlock, props);
    assert.match(readout(view.container), /^1\/4/, 'Reopening keeps the pending local value');
    await range(view.container, 'Numerator', 2);
    await tick(t);
    assert.equal(calls.length, 1, 'Reopening must share the same serialization queue');
    await act(async () => releases.shift()(true));
    assert.equal(calls.length, 2);
    assert.deepEqual(calls.at(-1).at(-1), { parts: 4, value: 2 });
  } finally {
    for (const release of releases) await act(async () => release(true));
    await view.close();
  }
});

test('failed Chat edits survive reopening and retain an explicit retry', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let succeeds = false;
  const props = chatState(async () => succeeds);
  let view = await mount(TeachingVisualBlock, props);
  try {
    await range(view.container, 'Denominator', 8);
    await tick(t);
    await view.close();
    view = await mount(TeachingVisualBlock, props);
    assert.match(readout(view.container), /^3\/8/);
    assert.match(view.container.querySelector('[role="status"]').textContent, /Could not save/);
    succeeds = true;
    await act(async () => [...view.container.querySelectorAll('button')].find(x => x.textContent === 'Retry').click());
    assert.equal(view.container.querySelector('[role="status"]'), null);
  } finally { await view.close(); }
});

test('changing active Chat cannot send an old message edit to the new conversation', async t => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const calls = [];
  const props = chatState(async (...args) => { calls.push(args); return true; });
  const view = await mount(TeachingVisualBlock, props);
  try {
    state.activeConversationId = 'conversation-2';
    await act(async () => view.root.render(React.createElement(TeachingVisualBlock, props)));
    await range(view.container, 'Numerator', 1);
    await tick(t);
    assert.equal(calls[0][0], 'conversation-1');
  } finally { await view.close(); }
});
