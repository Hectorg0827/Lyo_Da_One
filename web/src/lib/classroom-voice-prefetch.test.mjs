import test from 'node:test';
import assert from 'node:assert/strict';
import { SpeechPreparationCache, SpeechLookaheadQueue, playSpeechResponse, firstAudibleTurn, retryPlaybackAfterMoreAudio } from './classroom-audio.mjs';

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

test('only the earliest audible turn is eligible for speculative single-CPU prefetch', () => {
  const turns = [
    { type: 'write', text: '2/6 = 1/3' },
    { type: 'speech', speaker: 'Teacher', text: 'Look at the numerator.' },
    { type: 'user_prompt', speaker: 'Teacher', text: 'Your turn now.' },
    { type: 'speech', speaker: 'Lyo', text: 'You can do it!' },
  ];
  assert.equal(firstAudibleTurn(turns), turns[1]);
  assert.equal(firstAudibleTurn([{ type: 'speech', text: '  ' }, { type: 'pause' }]), undefined);
  const cache = new SpeechPreparationCache(1);
  assert.equal(cache.hasPending(), false);
  cache.prepare('first', () => Promise.resolve(new Response('audio')));
  assert.equal(cache.hasPending(), true);
  cache.take('first').controller.abort();
  assert.equal(cache.hasPending(), false);
});

test('one-ahead speech synthesis starts while the current phrase plays, not before', async () => {
  const calls = [];
  const segments = ['This is the variable.', 'Now solve the equation.', 'Explain your answer.'];
  const initial = Promise.resolve(new Response('first'));
  const queue = new SpeechLookaheadQueue(segments, async (text, index) => {
    calls.push([text, index]);
    return new Response(text);
  }, initial);

  assert.equal(await queue.take(0), await initial);
  assert.deepEqual(calls, [], 'no competing TTS request before first audio begins');
  const prefetched = queue.warmNext(0);
  assert.equal(queue.warmNext(0), prefetched, 'concurrent warm calls are deduplicated');
  await tick();
  assert.deepEqual(calls, [['Now solve the equation.', 1]]);
  assert.equal(await queue.take(1), await prefetched);
  assert.equal(queue.warmNext(1) !== null, true);
  await tick();
  assert.deepEqual(calls, [
    ['Now solve the equation.', 1], ['Explain your answer.', 2],
  ]);
  assert.equal(queue.warmNext(2), null);
  queue.clear();
});

test('canceled lookahead is safely consumed without an unhandled rejection', async () => {
  const controller = new AbortController();
  const queue = new SpeechLookaheadQueue(['First phrase.', 'Second phrase.'], async () => {
    if (controller.signal.aborted) throw new DOMException('Stopped', 'AbortError');
    return new Response('unexpected');
  });
  queue.warmNext(0);
  controller.abort();
  assert.equal(await queue.take(1), null);
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

test('a fragmentary first MP3 frame retries playback when more audio arrives', async () => {
  const f = fixture();
  let stream, attempts = 0;
  f.audio.play = async () => {
    attempts += 1;
    if (attempts === 1) {
      const error = new Error('decoder needs another frame');
      error.name = 'NotSupportedError';
      throw error;
    }
    f.audio.dispatchEvent(new Event('playing'));
  };
  const body = new ReadableStream({ start(controller) { stream = controller; } });
  const playback = playSpeechResponse(Promise.resolve(new Response(body, {
    headers: { 'Content-Type': 'audio/mpeg' },
  })), { ...f.options, signal: new AbortController().signal });
  stream.enqueue(new Uint8Array([1]));
  await tick();
  assert.equal(attempts, 1);
  stream.enqueue(new Uint8Array([2, 3, 4]));
  await tick();
  assert.equal(attempts, 2, 'a decoder fragment error is not fatal to the stream');
  stream.close();
  await tick();
  f.audio.dispatchEvent(new Event('ended'));
  await playback;
});

test('an unplayable completed stream does not retry forever', async () => {
  const f = fixture();
  let stream, attempts = 0;
  f.audio.play = async () => {
    attempts += 1;
    const error = new Error('unplayable MP3');
    error.name = 'NotSupportedError';
    throw error;
  };
  const body = new ReadableStream({ start(controller) { stream = controller; } });
  const playback = playSpeechResponse(Promise.resolve(new Response(body, {
    headers: { 'Content-Type': 'audio/mpeg' },
  })), { ...f.options, signal: new AbortController().signal });
  stream.enqueue(new Uint8Array([1]));
  stream.close();
  await assert.rejects(playback, /unplayable MP3/);
  assert.equal(attempts, 2, 'one final retry is allowed after EOF');
});

test('autoplay refusal is not treated as a recoverable decoder fragment', () => {
  assert.equal(retryPlaybackAfterMoreAudio({ name: 'NotAllowedError' }), false);
  assert.equal(retryPlaybackAfterMoreAudio({ name: 'NotSupportedError' }), true);
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
