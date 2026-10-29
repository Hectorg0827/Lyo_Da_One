import test from 'node:test';
import assert from 'node:assert/strict';
import { playVoiceBlob, speakVoiceFallback, unspokenRemainder } from './voice-playback.mjs';

function audioHarness(t) {
  const instances = [];
  const revoked = [];
  class Audio {
    constructor(src) { this.src = src; instances.push(this); }
    play() { this.onplaying?.(); return Promise.resolve(); }
    pause() { this.paused = true; }
    removeAttribute() { this.src = ''; }
    load() {}
  }
  t.mock.method(URL, 'createObjectURL', () => 'blob:test');
  t.mock.method(URL, 'revokeObjectURL', (url) => revoked.push(url));
  const previous = globalThis.Audio;
  globalThis.Audio = Audio;
  t.after(() => { globalThis.Audio = previous; });
  return { instances, revoked };
}

test('cancelling playback settles without browser end/error and releases the URL once', async (t) => {
  const { instances, revoked } = audioHarness(t);
  const controller = new AbortController();
  const progress = [];
  const playback = playVoiceBlob(new Blob(), { signal: controller.signal, onProgress: (p) => progress.push(p) });
  const staleEnd = instances[0].onended;
  const rejected = assert.rejects(playback, { name: 'AbortError' });
  controller.abort();
  staleEnd();
  await rejected;
  assert.deepEqual(progress, []);
  assert.deepEqual(revoked, ['blob:test']);
  assert.equal(instances[0].paused, true);
  assert.equal(instances[0].src, '');
});

test('already cancelled synthesis never creates an audio element', async (t) => {
  const { instances } = audioHarness(t);
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(playVoiceBlob(new Blob(), { signal: controller.signal }), { name: 'AbortError' });
  assert.equal(instances.length, 0);
});

test('normal playback completes and reports final progress', async (t) => {
  const { instances, revoked } = audioHarness(t);
  const progress = [];
  const playback = playVoiceBlob(new Blob(), { signal: new AbortController().signal, onProgress: (p) => progress.push(p) });
  instances[0].onended();
  await playback;
  assert.deepEqual(progress, [1]);
  assert.equal(revoked.length, 1);
});

test('device speech cancellation settles even when cancel emits no event', async (t) => {
  const oldSynth = globalThis.speechSynthesis;
  const oldUtterance = globalThis.SpeechSynthesisUtterance;
  let cancelled = false;
  globalThis.speechSynthesis = { speak() {}, cancel() { cancelled = true; } };
  globalThis.SpeechSynthesisUtterance = class {};
  t.after(() => { globalThis.speechSynthesis = oldSynth; globalThis.SpeechSynthesisUtterance = oldUtterance; });
  const controller = new AbortController();
  const playback = speakVoiceFallback('Hello', { signal: controller.signal });
  const rejected = assert.rejects(playback, { name: 'AbortError' });
  controller.abort();
  await rejected;
  assert.equal(cancelled, true);
});

test('a partial failure resumes from the unplayed portion', () => {
  assert.equal(unspokenRemainder('One two three four.', 0.5), 'three four.');
  assert.equal(unspokenRemainder('Already complete.', 1), '');
  assert.equal(unspokenRemainder('Not started.', 0), 'Not started.');
});
