import test from 'node:test';
import assert from 'node:assert/strict';
import { speakBrowserFallback } from './classroom-audio.mjs';

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
