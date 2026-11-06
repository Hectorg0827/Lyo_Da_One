import test from 'node:test';
import assert from 'node:assert/strict';
import { speakBrowserFallback, splitSpeechForStreaming, groupSpeechForProvider, SessionSpeechReplayCache, silentCaptionDelay } from './classroom-audio.mjs';

class FakeUtterance {
  constructor(text) { this.text = text; }
}

test('a local teacher voice can speak without a remote TTS provider', async () => {
  const events = [];
  const synth = {
    getVoices: () => [
      { name: 'Generic', lang: 'en-US' },
      { name: 'Jenny Natural', lang: 'en-US' },
      { name: 'Español', lang: 'es-ES' },
    ],
    cancel: () => {},
    speak: (utterance) => {
      events.push(utterance);
      queueMicrotask(() => {
        utterance.onstart?.();
        utterance.onend?.();
      });
    },
  };
  let started = 0;
  await speakBrowserFallback('Let us begin', {
    language: 'en-US', synth, Utterance: FakeUtterance,
    onStarted: () => { started += 1; },
  });
  assert.equal(started, 1);
  assert.equal(events[0].voice.name, 'Jenny Natural');
  assert.equal(events[0].lang, 'en-US');
});

test('the backup voice cancels when the student interrupts', async () => {
  const abort = new AbortController();
  let cancellations = 0;
  const synth = {
    getVoices: () => [{ name: 'Español', lang: 'es-ES' }],
    cancel: () => { cancellations += 1; },
    speak: (utterance) => {
      queueMicrotask(() => {
        utterance.onstart?.();
        abort.abort();
      });
    },
  };
  await assert.rejects(speakBrowserFallback('Empecemos', {
    language: 'es-ES', synth, Utterance: FakeUtterance, signal: abort.signal,
  }), /Playback interrupted/);
  assert.ok(cancellations >= 1);
});

test('device voice unavailable immediately, text-only lesson advances without a long silent voice wait', async () => {
  let cancellations = 0;
  const synth = {
    getVoices: () => [],
    cancel: () => { cancellations += 1; },
    speak: () => {}, // Browser accepted speak() but cannot start audio.
  };
  await assert.rejects(speakBrowserFallback('Teacher speaking', {
    synth, Utterance: FakeUtterance, startupTimeoutMs: 5,
  }), /did not start/);
  assert.ok(cancellations > 0);
  assert.ok(silentCaptionDelay('A long classroom explanation '.repeat(20)) <= 1800);
  assert.ok(silentCaptionDelay('Good!') >= 650);
});

test('teacher narration uses natural clause boundaries without losing or repeating words', () => {
  const line = 'First we compare equivalent fractions, then we check the denominators and explain the result clearly.';
  const chunks = splitSpeechForStreaming(line);
  assert.deepEqual(chunks, [
    'First we compare equivalent fractions,',
    'then we check the denominators and explain the result clearly.',
  ]);
  assert.equal(chunks.join(' '), line);
  assert.deepEqual(splitSpeechForStreaming(''), []);
  assert.deepEqual(splitSpeechForStreaming('One'), ['One']);
});

test('speech preserves whole sentences instead of cutting a natural explanation every few words', () => {
  const line = 'An equation shows two expressions are equal and helps us find the missing number.';
  assert.deepEqual(splitSpeechForStreaming(line), [line]);
});

test('math notation, decimals, abbreviation, and quoted sentence boundaries remain intact', () => {
  const line = 'Dr. Rivera asks: "What is 4x + 7 when x is 3.5?" We can substitute the value and solve.';
  const chunks = splitSpeechForStreaming(line);
  assert.equal(chunks.join(' '), line);
  assert.ok(chunks.every((chunk) => !chunk.endsWith('Dr.')));
  assert.ok(chunks.some((chunk) => chunk.endsWith('?"')));
  assert.ok(chunks.some((chunk) => chunk.includes('3.5?')));
});

test('long punctuation-free speech remains bounded and all words are retained', () => {
  const line = Array.from({ length: 52 }, (_, i) => `fraction${i}`).join(' ');
  const chunks = splitSpeechForStreaming(line);
  assert.ok(chunks.length > 1);
  assert.ok(chunks.every((chunk) => chunk.length <= 190));
  assert.equal(chunks.join(' '), line);
});

test('brief acknowledgments and Spanish questions remain one natural utterance', () => {
  assert.deepEqual(splitSpeechForStreaming('Exactly!'), ['Exactly!']);
  assert.deepEqual(splitSpeechForStreaming('¿Cuál es la variable?'), ['¿Cuál es la variable?']);
});

test('native streaming renders a typical teacher line once rather than once per clause', () => {
  const teacherLine = 'First we compare equivalent fractions, then we check the denominators and explain the result clearly.';
  assert.deepEqual(groupSpeechForProvider(teacherLine), [teacherLine]);
  assert.deepEqual(groupSpeechForProvider('Exactly!'), ['Exactly!']);
  assert.deepEqual(groupSpeechForProvider(''), []);
});

test('unusually long teacher turns keep bounded natural provider requests with no lost words', () => {
  const line = Array.from({ length: 52 }, (_, i) => `fraction${i}`).join(' ');
  const requests = groupSpeechForProvider(line, 250);
  assert.ok(requests.length > 1);
  assert.ok(requests.every(request => request.length <= 250));
  assert.equal(requests.join(' '), line);
});

test('short completed teacher clips replay from a bounded memory cache', async () => {
  const cache = new SessionSpeechReplayCache(2, 12, 8);
  const contentType = { headers: { 'Content-Type': 'audio/mpeg' } };
  assert.equal(await cache.remember('a', new Response('four', contentType)), true);
  assert.equal(cache.totalBytes, 4);
  const replay = cache.get('a');
  assert.equal(replay?.headers.get('Content-Type'), 'audio/mpeg');
  assert.equal(await replay.text(), 'four');
  assert.equal(await cache.remember('b', new Response('five5', contentType)), true);
  assert.equal(await cache.get('a').text(), 'four', 'reading a clip renews its LRU position');
  assert.equal(await cache.remember('c', new Response('six666', contentType)), true);
  assert.equal(cache.get('a')?.status, 200, 'recently replayed entry remains present');
  assert.equal(cache.get('b'), null, 'oldest clip was evicted');
  assert.equal(cache.totalBytes, 10);
  cache.clear();
  assert.equal(cache.get('a'), null);
  assert.equal(cache.totalBytes, 0);
});

test('partial, oversized, and interrupted teacher recordings never enter replay cache', async () => {
  const cache = new SessionSpeechReplayCache(3, 30, 4);
  assert.equal(await cache.remember('oversized', new Response('fivex')), false);
  assert.equal(cache.get('oversized'), null);

  const controller = new AbortController();
  let stream;
  const response = new Response(new ReadableStream({ start(c) { stream = c; } }));
  const pending = cache.remember('aborted', response, controller.signal);
  stream.enqueue(new Uint8Array([1, 2]));
  controller.abort();
  stream.close();
  assert.equal(await pending, false);
  assert.equal(cache.get('aborted'), null);
});
