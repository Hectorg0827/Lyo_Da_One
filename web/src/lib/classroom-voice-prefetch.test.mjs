import test from 'node:test';
import assert from 'node:assert/strict';
import { SpeechPreparationCache, playSpeechResponse } from './classroom-audio.mjs';

const tick = () => new Promise(resolve => setImmediate(resolve));
class FakeAudio extends EventTarget {
  plays = 0;
  pause() { this.paused = true; }
  removeAttribute() {}
  load() {}
  async play() { this.plays++; this.dispatchEvent(new Event('playing')); }
  set src(value) { this.source = value; }
}
function fixture() {
  const audio = new FakeAudio();
  let media, downloads = 0;
  class FakeMediaSource extends EventTarget {
    static isTypeSupported(mime) { return mime === 'audio/mpeg'; }
    constructor() { super(); media = this; this.readyState = 'open'; }
    addSourceBuffer() {
      const buffer = new EventTarget();
      buffer.appendBuffer = () => queueMicrotask(() => buffer.dispatchEvent(new Event('updateend')));
      return buffer;
    }
    endOfStream() { downloads++; }
  }
  return {
    audio, get downloads() { return downloads; },
    options: {
      createAudio: () => audio, MediaSourceClass: FakeMediaSource,
      urls: { createObjectURL() { queueMicrotask(() => media.dispatchEvent(new Event('sourceopen'))); return 'blob:voice'; }, revokeObjectURL() {} },
    },
  };
}

test('prefetch is bounded, deduplicated, and canceled when the learner changes direction', async () => {
  const cache = new SpeechPreparationCache(2);
  const signals = [];
  const load = async signal => { signals.push(signal); return new Response('audio'); };
  cache.prepare('a', load); cache.prepare('a', load); cache.prepare('b', load); cache.prepare('c', load);
  await tick();
  assert.equal(signals.length, 3);
  assert.equal(signals[0].aborted, true);
  const active = cache.take('b');
  cache.clear();
  assert.equal(active.controller.signal.aborted, false); // player owns it now
  assert.equal(signals[2].aborted, true);
  active.controller.abort();
});

test('speech starts before the final bytes arrive; download completion does not advance the lesson', async () => {
  const f = fixture();
  let stream;
  const body = new ReadableStream({ start(c) { stream = c; } });
  const controller = new AbortController();
  let finished = false;
  const playback = playSpeechResponse(Promise.resolve(new Response(body, { headers: { 'Content-Type': 'audio/mpeg' } })), {
    ...f.options, signal: controller.signal,
  }).then(() => { finished = true; });
  stream.enqueue(new Uint8Array([1, 2]));
  await tick();
  assert.equal(f.audio.plays, 1);
  assert.equal(f.downloads, 0);
  stream.enqueue(new Uint8Array([3])); stream.close();
  await tick();
  assert.equal(f.downloads, 1);
  assert.equal(finished, false);
  f.audio.dispatchEvent(new Event('ended'));
  await playback;
  assert.equal(finished, true);
  assert.equal(f.audio.paused, true);
});

test('interrupting during the download stops audio and cancels the reader', async () => {
  const f = fixture(); let stream, canceled = false;
  const body = new ReadableStream({ start(c) { stream = c; }, cancel() { canceled = true; } });
  const controller = new AbortController();
  const playback = playSpeechResponse(Promise.resolve(new Response(body, { headers: { 'Content-Type': 'audio/mpeg' } })), {
    ...f.options, signal: controller.signal,
  });
  stream.enqueue(new Uint8Array([1])); await tick();
  controller.abort();
  await assert.rejects(playback, { name: 'AbortError', playbackStarted: true });
  assert.equal(canceled, true);
  assert.equal(f.audio.paused, true);
});

test('a late voice response cannot speak after interruption', async () => {
  const f = fixture(); let resolve;
  const pending = new Promise(r => { resolve = r; });
  const controller = new AbortController();
  const playback = playSpeechResponse(pending, { ...f.options, signal: controller.signal });
  controller.abort();
  await assert.rejects(playback, { name: 'AbortError' });
  resolve(new Response('late')); await tick();
  assert.equal(f.audio.plays, 0);
});

test('unsupported streaming keeps a single buffered download and advances only at audio end', async () => {
  const audio = new FakeAudio();
  const playback = playSpeechResponse(Promise.resolve(new Response('mp3')), {
    signal: new AbortController().signal, createAudio: () => audio,
    MediaSourceClass: undefined,
    urls: { createObjectURL: () => 'blob:voice', revokeObjectURL() {} },
  });
  await tick(); assert.equal(audio.plays, 1);
  audio.dispatchEvent(new Event('ended')); await playback;
});

test('unavailable provider fails within a bounded startup deadline', async () => {
  const f = fixture();
  await assert.rejects(playSpeechResponse(new Promise(() => {}), {
    ...f.options, signal: new AbortController().signal, startupTimeoutMs: 5,
  }), /startup timed out/);
  assert.equal(f.audio.plays, 0);
});
