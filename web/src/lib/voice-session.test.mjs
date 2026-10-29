import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { JSDOM } from 'jsdom';
import React, { act } from 'react';
import { createRoot } from 'react-dom/client';
import ts from 'typescript';
import * as transcripts from './speech-transcript.mjs';
import * as reveal from './voice-reveal.mjs';
import * as barge from './voice-barge-in.mjs';
import * as playback from './voice-playback.mjs';

const require = createRequire(import.meta.url);
function compile(path, dependencies = {}) {
  const code = ts.transpileModule(readFileSync(new URL(path, import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', code)((name) => dependencies[name] ?? require(name), module, module.exports);
  return module.exports;
}
const conversational = compile('./conversational-voice.ts');
const flush = async (callback = () => {}) => act(async () => { callback(); await Promise.resolve(); });

async function harness(t, { android = true, delayed = false, monitor = 'failed' } = {}) {
  const dom = new JSDOM('<div id="root"></div>', { url: 'https://lyo.test/chat' });
  const restore = [];
  const setGlobal = (name, value) => {
    const descriptor = Object.getOwnPropertyDescriptor(globalThis, name);
    restore.push(() => descriptor ? Object.defineProperty(globalThis, name, descriptor) : delete globalThis[name]);
    Object.defineProperty(globalThis, name, { value, configurable: true, writable: true });
  };
  setGlobal('window', dom.window);
  setGlobal('document', dom.window.document);
  const tracks = [{ stopped: false, stop() { this.stopped = true; } }];
  let grantMonitor;
  const monitorPromise = new Promise((resolve) => { grantMonitor = () => resolve({ getTracks: () => tracks }); });
  setGlobal('navigator', { language: 'en-US', userAgent: android ? 'Android Chrome' : 'Chrome Desktop',
    mediaDevices: { async getUserMedia() {
      captures++;
      if (monitor === 'ready') return { getTracks: () => tracks };
      if (monitor === 'delayed') return monitorPromise;
      throw new Error('Capture refused');
    } } });
  setGlobal('IS_REACT_ACT_ENVIRONMENT', true);
  let frame, level = 128, now = 1000;
  t.mock.method(performance, 'now', () => now);
  setGlobal('requestAnimationFrame', (fn) => { frame = fn; return 1; });
  dom.window.AudioContext = class {
    state = 'running';
    createMediaStreamSource() { return { connect() {} }; }
    createAnalyser() { return { fftSize: 512, getByteTimeDomainData(samples) { samples.fill(level); } }; }
    async close() { this.state = 'closed'; }
  };
  setGlobal('cancelAnimationFrame', () => {});
  let captures = 0;
  const recognizers = [], audios = [], utterances = [], requests = [], submissions = [], telemetry = [];
  class Recognition {
    constructor() { recognizers.push(this); }
    start() { this.running = true; }
    abort() { this.running = false; }
    stop() { this.running = false; }
    result(text) { this.onresult?.({ results: [{ 0: { transcript: text, confidence: 1 }, length: 1, isFinal: false }] }); }
  }
  dom.window.SpeechRecognition = Recognition;
  setGlobal('Audio', class {
    constructor() { audios.push(this); this.duration = 10; this.currentTime = 0; }
    play() { this.onplaying?.(); return Promise.resolve(); }
    pause() { this.paused = true; }
    removeAttribute() {}
    load() {}
  });
  setGlobal('SpeechSynthesisUtterance', class { constructor(text) { this.text = text; } });
  const synth = { cancel() {}, speak(utterance) { utterances.push(utterance); utterance.onstart?.(); } };
  setGlobal('speechSynthesis', synth);
  dom.window.speechSynthesis = synth;
  t.mock.method(URL, 'createObjectURL', () => 'blob:test');
  t.mock.method(URL, 'revokeObjectURL', () => {});
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let listener;
  const subscriptions = new Set();
  const update = (patch) => { state = { ...state, ...patch }; subscriptions.forEach((fn) => fn()); };
  let state = {
    voiceSessionActive: true, isGenerating: false, activeConversationId: 'conversation-1',
    setVoiceSessionActive: (value) => update({ voiceSessionActive: value }),
    setVoiceSpokenText: () => {},
    getActiveConversation: () => ({ messages: [] }),
    interruptGeneration: () => update({ isGenerating: false }),
    sendMessage: async (text, attachments, options) => { submissions.push({ text, options }); update({ isGenerating: true }); },
  };
  const store = (select) => select(React.useSyncExternalStore((fn) => { subscriptions.add(fn); return () => subscriptions.delete(fn); }, () => state));
  store.getState = () => state;
  const { default: Layer } = compile('../components/chat/ConversationalVoiceLayer.tsx', {
    '@/lib/api': { api: { tts: { synthesizeStream(text, options) {
      let resolve;
      const promise = new Promise((r) => { resolve = r; });
      requests.push({ text, options, resolve });
      if (!delayed) resolve(new Blob(['audio']));
      return promise;
    } } } },
    '@/lib/utils': { cn: (...classes) => classes.filter(Boolean).join(' ') },
    '@/stores/chat-store': { useChatStore: store },
    '@/lib/speech-transcript.mjs': transcripts,
    '@/lib/voice-reveal.mjs': reveal,
    '@/lib/voice-barge-in.mjs': barge,
    '@/lib/voice-playback.mjs': playback,
    '@/lib/voice-quality': {
      createVoiceQualitySessionId: () => crypto.randomUUID(), detectLanguageFamily: () => 'en',
      reportVoiceQuality: (_context, event, metrics) => telemetry.push({ event, metrics }),
      setActiveVoiceQualityContext() {}, voiceQualityNow: () => performance.now(),
    },
    '@/lib/conversational-voice': { ...conversational, subscribeVoiceStreamEvents(fn) { listener = fn; return () => { listener = null; }; } },
  });
  const root = createRoot(document.getElementById('root'));
  await flush(() => root.render(React.createElement(Layer)));
  t.after(async () => {
    await flush(() => root.unmount());
    t.mock.timers.reset();
    dom.window.close();
    restore.reverse().forEach((fn) => fn());
  });
  const emit = (event, index = submissions.length - 1) => flush(() => listener?.({
    messageId: `assistant-${index}`, turnId: submissions[index].options.voiceTurnId, ...event,
  }));
  return {
    recognizers, audios, requests, submissions, utterances, telemetry, tracks,
    async grantMonitor() { await flush(() => grantMonitor()); },
    async frames(sample, count = 6) {
      await flush(() => { level = sample; for (let i = 0; i < count; i++) { now += 50; frame(); } });
    },
    get captures() { return captures; },
    text: () => document.body.textContent,
    async say(text) {
      await flush(() => recognizers.at(-1).result(text));
      await flush(() => t.mock.timers.tick(conversational.voiceEndOfTurnDelayMs(text)));
    },
    emit,
    async ready() { await emit({ type: 'voice_ready', text: 'Done.', speak: true }); await flush(() => update({ isGenerating: false })); },
    async click(label) {
      await flush(() => [...document.querySelectorAll('button')].find((b) => b.textContent === label).click());
    },
    async restart() { await flush(() => update({ voiceSessionActive: true })); },
  };
}

test('Android plays its answer without another mic capture or phantom echo turn', async (t) => {
  const h = await harness(t);
  const oldRecognizer = h.recognizers.at(-1);
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'Gravity attracts matter.', sequence: 0 });
  await flush(() => oldRecognizer.result('distorted speaker words'));
  assert.equal(h.captures, 0);
  assert.equal(h.recognizers.filter((r) => r.running).length, 0);
  assert.equal(h.audios.length, 1);
  assert.match(h.text(), /tap Interrupt/);
  await h.ready();
  await flush(() => h.audios[0].onended());
  assert.match(h.text(), /Listening/);
  assert.equal(h.recognizers.at(-1).running, true);
  assert.equal(h.submissions.length, 1);
  await h.say('Gravity attracts matter.');
  assert.equal(h.submissions.length, 2, 'genuine repetition after playback is accepted');
});

test('tap during delayed synthesis rejects old audio, stream events and recognizer callbacks', async (t) => {
  const h = await harness(t, { delayed: true });
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'Old reply.', sequence: 0 });
  const staleRecognizer = h.recognizers.at(-1);
  await h.click('Interrupt');
  await h.say('Now explain trees.');
  await h.emit({ type: 'voice_text_segment', text: 'New reply.', sequence: 0 });
  await flush(() => { h.requests[0].resolve(new Blob()); staleRecognizer.onend?.(); });
  await h.emit({ type: 'voice_text_segment', text: 'Old late reply.', sequence: 1 }, 0);
  assert.equal(h.requests.length, 2);
  assert.equal(h.audios.length, 0);
  await flush(() => h.requests[1].resolve(new Blob()));
  assert.equal(h.audios.length, 1);
  assert.equal(h.utterances.length, 0, 'cancellation cannot trigger device fallback');
  assert.equal(h.submissions[1].options.voiceInterruptedPreviousTurn, true);
});

test('tap cancels audible playback and immediately listens', async (t) => {
  const h = await harness(t);
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'Gravity attracts matter.', sequence: 0 });
  const staleEnd = h.audios[0].onended;
  await h.click('Interrupt');
  await flush(() => staleEnd());
  assert.equal(h.audios[0].paused, true);
  assert.equal(h.recognizers.at(-1).running, true);
  assert.match(h.text(), /Listening/);
  assert.equal(h.utterances.length, 0);
});

test('failed audio speaks only its remainder and proceeds to the next segment', async (t) => {
  const h = await harness(t);
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'One two three four.', sequence: 0 });
  await h.emit({ type: 'voice_text_segment', text: 'Next sentence.', sequence: 1 });
  await flush(() => {
    h.audios[0].currentTime = 5;
    h.audios[0].ontimeupdate();
    h.audios[0].onerror();
  });
  assert.equal(h.utterances[0].text, 'three four.');
  await flush(() => h.utterances[0].onend());
  assert.equal(h.audios.length, 2);
  await h.ready();
  await flush(() => h.audios[1].onended());
  assert.match(h.text(), /Listening/);
});

test('ending and restarting a session discards old synthesis and clears timers', async (t) => {
  const h = await harness(t, { delayed: true });
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'Old answer.', sequence: 0 });
  await h.click('End');
  await h.restart();
  await h.say('A new question.');
  await flush(() => h.requests[0].resolve(new Blob()));
  await h.emit({ type: 'voice_ready', text: 'Old answer.', speak: true }, 0);
  assert.equal(h.audios.length, 0);
  assert.equal(h.requests.length, 1);
  assert.notEqual(h.submissions[0].options.voiceTurnId, h.submissions[1].options.voiceTurnId);
  assert.match(h.text(), /thinking/);
});

test('desktop monitor failure keeps playback intact and offers tap interruption', async (t) => {
  const h = await harness(t, { android: false });
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'An answer.', sequence: 0 });
  assert.equal(h.captures, 1);
  assert.match(h.text(), /tap Interrupt/);
  assert.equal(h.audios.length, 1);
  assert.equal(h.recognizers.filter((r) => r.running).length, 0);
  await h.click('Interrupt');
  assert.match(h.text(), /Listening/);
});


test('ready desktop monitoring rejects echo but accepts corroborated new speech', async (t) => {
  const h = await harness(t, { android: false, monitor: 'ready' });
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'Gravity attracts matter.', sequence: 0 });
  assert.match(h.text(), /start talking to interrupt/);
  await flush(() => h.recognizers.at(-1).result('Gravity attracts matter.'));
  assert.equal(h.audios[0].paused, undefined);
  await h.frames(130, 10);
  await h.frames(170);
  await flush(() => h.recognizers.at(-1).result('Tell me about plants.'));
  assert.equal(h.audios[0].paused, true);
  assert.equal(h.tracks[0].stopped, true);
  await flush(() => t.mock.timers.tick(430));
  assert.equal(h.submissions[1].text, 'Tell me about plants.');
  assert.equal(h.submissions[1].options.voiceInterruptedPreviousTurn, true);
});

test('late microphone permission after interruption releases the capture', async (t) => {
  const h = await harness(t, { android: false, monitor: 'delayed' });
  await h.say('Explain gravity.');
  await h.emit({ type: 'voice_text_segment', text: 'An answer.', sequence: 0 });
  await h.click('Interrupt');
  await h.grantMonitor();
  assert.equal(h.tracks[0].stopped, true);
  assert.match(h.text(), /Listening/);
  assert.equal(h.recognizers.filter((r) => r.running).length, 1);
});
