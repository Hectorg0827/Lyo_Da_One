import test from 'node:test';
import assert from 'node:assert/strict';
import { speakBrowserFallback, splitSpeechForStreaming } from './classroom-audio.mjs';

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
