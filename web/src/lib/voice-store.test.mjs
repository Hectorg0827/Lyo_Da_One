import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import ts from 'typescript';
import * as teaching from './teaching-runtime.mjs';
import * as study from './study-material.mjs';
import * as visuals from './teaching-visuals.mjs';
const require = createRequire(import.meta.url);
const compiled = ts.transpileModule(readFileSync(new URL('../stores/chat-store.ts', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true },
}).outputText;
const deferred = () => { let resolve; const promise = new Promise((r) => { resolve = r; }); return { promise, resolve }; };
const settle = async () => { for (let i = 0; i < 8; i++) await Promise.resolve(); };
function harness({ local = false } = {}) {
  const creation = deferred(), recovery = deferred(), streams = [], errors = [], events = [];
  let counter = 0;
  const modules = {
    '@/lib/utils': { generateId: () => `generated-${++counter}` },
    '@/lib/api': { api: { chat: {
      createConversation: () => creation.promise,
      conversation: () => recovery.promise,
      stream(...args) { const controller = new AbortController(); streams.push({ args, controller }); return controller; },
    } } },
    '@/lib/chat-attachments': { parseCanonicalChatContent: (text) => ({ text, attachments: [] }) },
    '@/lib/conversational-voice': { publishVoiceStreamEvent: (event) => events.push(event) },
    '@/lib/voice-quality': { reportActiveVoiceQuality() {}, voiceQualityNow: () => 1000 },
    '@/lib/teaching-runtime.mjs': teaching,
    '@/lib/study-material.mjs': study,
    '@/lib/teaching-visuals.mjs': visuals,
    '@/lib/commons-image.mjs': { resolveCommonsImage: async () => null },
    'react-hot-toast': { error: (message) => errors.push(message), success() {} },
  };
  const module = { exports: {} };
  new Function('require', 'module', 'exports', compiled)((name) => modules[name] ?? require(name), module, module.exports);
  const store = module.exports.useChatStore;
  const id = local ? 'local-chat' : 'remote-chat';
  store.setState({ activeConversationId: id, voiceSessionActive: true, conversations: [{
    id, title: 'Voice chat', messages: [], createdAt: '', updatedAt: '',
  }] });
  const detail = { id, title: 'Recovered', messages: [], created_at: '', updated_at: '' };
  const send = (text) => store.getState().sendMessage(text, [], { voiceSession: true, voiceTurnId: text });
  return { store, send, creation, recovery, streams, errors, events, detail };
}

test('interrupting while the first chat is being created cannot start an obsolete stream', async () => {
  const h = harness({ local: true });
  const pending = h.send('First request.');
  h.store.getState().interruptGeneration();
  h.creation.resolve({ id: 'created-remote', title: 'New', created_at: '', updated_at: '' });
  await pending;
  assert.equal(h.streams.length, 0);
  assert.equal(h.store.getState().isGenerating, false);
  assert.equal(h.store.getState().activeConversationId, 'local-chat');
});

test('late recovery cannot replace a newer voice turn or report its failure', async () => {
  const h = harness();
  await h.send('First request.');
  h.streams[0].args[4]();
  h.store.getState().interruptGeneration();
  await h.send('New request.');
  h.recovery.resolve(h.detail);
  await settle();
  const current = h.store.getState();
  assert.equal(current.isGenerating, true);
  assert.ok(current.getActiveConversation().messages.some((m) => m.content === 'New request.'));
  assert.equal(h.errors.length, 0);
});

test('sidebar loading a different chat ends voice and cancels the old stream', async () => {
  const h = harness();
  await h.send('First request.');
  const load = h.store.getState().loadConversation('other-chat');
  assert.equal(h.store.getState().voiceSessionActive, false);
  assert.equal(h.streams[0].controller.signal.aborted, true);
  h.recovery.resolve({ ...h.detail, id: 'other-chat' });
  await load;
});
