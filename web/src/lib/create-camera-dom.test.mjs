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
const dom = new JSDOM('<!doctype html><body></body>', { url: 'https://localhost/create' });
Object.assign(globalThis, {
  window: dom.window,
  document: dom.window.document,
  DOMException: dom.window.DOMException,
  File: dom.window.File,
  Blob: dom.window.Blob,
  HTMLElement: dom.window.HTMLElement,
  SVGElement: dom.window.SVGElement,
  IS_REACT_ACT_ENVIRONMENT: true,
});
Object.defineProperty(globalThis, 'navigator', { value: dom.window.navigator, configurable: true });
dom.window.HTMLMediaElement.prototype.play = () => Promise.resolve();
const React = require('react');
const { act } = React;
const { createRoot } = require('react-dom/client');

const mocks = {
  'framer-motion': {
    AnimatePresence: ({ children }) => children,
    motion: { div: ({ children, initial, animate, exit, ...props }) => React.createElement('div', props, children) },
  },
  'react-hot-toast': { __esModule: true, default: { success() {}, error() {} } },
  'next/navigation': { useRouter: () => ({ push() {} }) },
  '@/lib/utils': { cn: (...parts) => parts.filter(Boolean).join(' ') },
  '@/lib/api': { api: {} },
  '@/lib/launch-features': { COMMUNITY_LAUNCH_ENABLED: false, DISCOVER_LAUNCH_ENABLED: true },
  '@/components/clips/CreateClipModal': {
    __esModule: true,
    default: ({ initialSource, onClose }) => React.createElement('div', { 'data-clip-source': initialSource },
      React.createElement('button', { onClick: onClose }, 'Close clip composer')),
  },
};
const loaded = new Map();
function load(filename) {
  if (loaded.has(filename)) return loaded.get(filename).exports;
  const mod = new Module(filename);
  mod.filename = filename;
  mod.paths = Module._nodeModulePaths(webRoot);
  loaded.set(filename, mod);
  mod.require = name => {
    if (Object.hasOwn(mocks, name)) return mocks[name];
    if (name.startsWith('@/') || name.startsWith('./')) {
      const base = name.startsWith('@/') ? path.join(webRoot, 'src', name.slice(2)) :
        path.resolve(path.dirname(filename), name);
      const file = ['.tsx', '.ts'].map(ext => base + ext).find(existsSync);
      if (file) return load(file);
    }
    return require(name);
  };
  mod._compile(ts.transpileModule(readFileSync(filename, 'utf8'), { compilerOptions: {
    jsx: ts.JsxEmit.ReactJSX,
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2020,
  } }).outputText, filename);
  return mod.exports;
}
async function mount(t, component) {
  const container = document.createElement('div');
  document.body.append(container);
  const root = createRoot(container);
  await act(async () => root.render(component));
  t.after(async () => { await act(async () => root.unmount()); container.remove(); });
  return container;
}
const click = async button => {
  assert.ok(button, 'expected button exists');
  await act(async () => button.click());
};
const buttonNamed = (scope, label) =>
  [...scope.querySelectorAll('button')].find(button => button.textContent.includes(label));

test('Create offers direct Camera and Upload actions that preserve the chosen source', async t => {
  const { default: CreateSheet } = load(path.join(webRoot, 'src/components/create/CreateSheet.tsx'));
  await mount(t, React.createElement(CreateSheet, { isOpen: true, onClose() {} }));
  await click(buttonNamed(document.body, 'Clip'));
  assert.ok(buttonNamed(document.body, 'Use camera'));
  assert.ok(buttonNamed(document.body, 'Upload video'));
  await click(buttonNamed(document.body, 'Use camera'));
  assert.equal(document.querySelector('[data-clip-source]')?.getAttribute('data-clip-source'), 'camera');
  await click(buttonNamed(document.body, 'Close clip composer'));
  await click(buttonNamed(document.body, 'Upload video'));
  assert.equal(document.querySelector('[data-clip-source]')?.getAttribute('data-clip-source'), 'upload');
});

test('camera records a real media chunk, provides a publishable File, and releases hardware', async t => {
  let stoppedTracks = 0;
  const stream = { getTracks: () => [{ stop: () => { stoppedTracks += 1; } }] };
  Object.defineProperty(navigator, 'mediaDevices', {
    configurable: true,
    value: { getUserMedia: async () => stream },
  });
  class Recorder {
    static isTypeSupported(type) { return type.startsWith('video/mp4'); }
    constructor() { this.mimeType = 'video/mp4'; this.state = 'inactive'; }
    start() { this.state = 'recording'; }
    stop() {
      this.state = 'inactive';
      this.ondataavailable?.({ data: new Blob(['recorded camera bytes'], { type: 'video/mp4' }) });
      this.onstop?.();
    }
  }
  globalThis.MediaRecorder = Recorder;
  const received = [];
  const errors = [];
  const { default: CameraRecorder } = load(path.join(webRoot, 'src/components/clips/CameraRecorder.tsx'));
  const view = await mount(t, React.createElement(CameraRecorder, {
    onCaptured: file => received.push(file),
    onError: message => errors.push(message),
  }));
  await click(buttonNamed(view, 'Enable camera'));
  await click(buttonNamed(view, 'Start recording'));
  await click(buttonNamed(view, 'Stop'));
  assert.equal(received.length, 1);
  assert.equal(received[0].type, 'video/mp4');
  assert.ok(received[0].size > 0);
  assert.ok(stoppedTracks > 0, 'camera tracks are stopped after recording');
  assert.equal(errors.filter(Boolean).length, 0);
});

test('denied camera permission gives a visible error and never creates a fake clip', async t => {
  Object.defineProperty(navigator, 'mediaDevices', {
    configurable: true,
    value: { getUserMedia: async () => { throw new DOMException('denied', 'NotAllowedError'); } },
  });
  const errors = [];
  const recorded = [];
  const { default: CameraRecorder } = load(path.join(webRoot, 'src/components/clips/CameraRecorder.tsx'));
  const view = await mount(t, React.createElement(CameraRecorder, {
    onCaptured: file => recorded.push(file),
    onError: message => errors.push(message),
  }));
  await click(buttonNamed(view, 'Enable camera'));
  assert.match(errors.at(-1), /access was denied/i);
  assert.equal(recorded.length, 0);
});

test('closing Create while a camera is active stops the stream without publishing', async () => {
  let trackStops = 0;
  Object.defineProperty(navigator, 'mediaDevices', {
    configurable: true,
    value: { getUserMedia: async () => ({ getTracks: () => [{ stop: () => { trackStops += 1; } }] }) },
  });
  const recorded = [];
  const { default: CameraRecorder } = load(path.join(webRoot, 'src/components/clips/CameraRecorder.tsx'));
  const host = document.createElement('div');
  document.body.append(host);
  const root = createRoot(host);
  await act(async () => root.render(React.createElement(CameraRecorder, {
    onCaptured: file => recorded.push(file),
    onError() {},
  })));
  await click(buttonNamed(host, 'Enable camera'));
  await act(async () => root.unmount());
  host.remove();
  assert.ok(trackStops > 0, 'unmount released the camera');
  assert.equal(recorded.length, 0);
});
