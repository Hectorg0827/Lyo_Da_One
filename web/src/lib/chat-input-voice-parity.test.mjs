import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { JSDOM } from 'jsdom';
import React, { act } from 'react';
import { createRoot } from 'react-dom/client';
import ts from 'typescript';

const require = createRequire(import.meta.url);

function compile(path, dependencies) {
  const code = ts.transpileModule(readFileSync(new URL(path, import.meta.url), 'utf8'), {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      jsx: ts.JsxEmit.ReactJSX,
      esModuleInterop: true,
    },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', code)(
    (name) => dependencies[name] ?? require(name), module, module.exports,
  );
  return module.exports;
}

test('Web chat exposes the same one-row live mic, attachment and send controls as Android', async (t) => {
  const dom = new JSDOM('<div id="root"></div>', { url: 'https://lyo.test/chat' });
  const original = new Map();
  for (const [name, value] of [
    ['window', dom.window],
    ['document', dom.window.document],
    ['IS_REACT_ACT_ENVIRONMENT', true],
  ]) {
    original.set(name, Object.getOwnPropertyDescriptor(globalThis, name));
    Object.defineProperty(globalThis, name, { value, configurable: true, writable: true });
  }
  dom.window.SpeechRecognition = class {};

  const state = {
    sendMessage: async () => {},
    isGenerating: false,
    generationActivity: 'response',
    reviseActiveCourse: async () => {},
    voiceSessionActive: false,
    setVoiceSessionActive: (active) => { state.voiceSessionActive = active; },
  };
  const icon = () => React.createElement('svg', { 'aria-hidden': 'true' });
  const motion = new Proxy({}, { get: (_, element) => (props) => {
    const { whileTap: _whileTap, initial: _initial, animate: _animate,
      exit: _exit, transition: _transition, ...rest } = props;
    return React.createElement(element, rest);
  } });
  const { default: ChatInputBar } = compile('../components/chat/ChatInputBar.tsx', {
    'framer-motion': { motion, AnimatePresence: ({ children }) => React.createElement(React.Fragment, null, children) },
    'lucide-react': Object.fromEntries(['ArrowUp', 'Plus', 'Mic', 'Square', 'X', 'FileText', 'Loader2'].map((name) => [name, icon])),
    'react-hot-toast': { error() {} },
    '@/lib/utils': { cn: (...classes) => classes.filter(Boolean).join(' ') },
    '@/stores/chat-store': { useChatStore: () => state },
    '@/lib/api': { api: { media: { upload: async () => ({}) } } },
    '@/lib/browser-speech': { createBrowserSpeechRecognition: () => ({}) },
    './ConversationalVoiceLayer': () => null,
  });
  const root = createRoot(document.getElementById('root'));
  const render = () => act(async () => { root.render(React.createElement(ChatInputBar)); });
  await render();
  t.after(async () => {
    await act(async () => root.unmount());
    dom.window.close();
    for (const [name, descriptor] of original) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor);
      else delete globalThis[name];
    }
  });

  const island = document.querySelector('.input-island');
  assert.ok(island);
  const attach = island.querySelector('button[aria-label="Attach an image or document"]');
  const microphone = island.querySelector('button[aria-label="Start live voice"]');
  const send = island.querySelector('button[aria-label="Send message"]');
  const message = island.querySelector('textarea[aria-label="Message Lyo"]');
  assert.ok(attach && microphone && send && message, 'the four Android controls share one island');
  assert.equal(attach.parentElement, island);
  assert.equal(microphone.parentElement, island);
  assert.equal(send.parentElement, island);
  assert.equal(message.parentElement.parentElement, island);
  assert.equal(island.querySelectorAll('button[aria-label*="voice"]').length, 1);
  assert.equal(send.disabled, true);

  await act(async () => microphone.click());
  assert.equal(state.voiceSessionActive, true);
  await render();
  const stop = island.querySelector('button[aria-label="End live voice"]');
  assert.ok(stop);
  assert.equal(stop.getAttribute('aria-pressed'), 'true');

  await act(async () => stop.click());
  assert.equal(state.voiceSessionActive, false);
});
