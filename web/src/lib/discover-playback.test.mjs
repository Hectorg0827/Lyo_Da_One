import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DiscoverPlaybackController, DiscoverPageCursor, mergeClipPage, nextClipIndex } from './discover-playback.mjs';

const active = { selected: true, foreground: true, paused: false, scrubbing: false, failed: false };
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
const tick = () => new Promise((resolve) => setImmediate(resolve));
function setup() {
  const pending = [];
  const video = { duration: 12, currentTime: 0, paused: true, play() { this.paused = false; const p = deferred(); pending.push(p); return p.promise; }, pause() { this.paused = true; } };
  let blocked = 0, failed = 0;
  const controller = new DiscoverPlaybackController(video, { onBlocked: () => ++blocked, onError: () => ++failed });
  return { controller, video, pending, errors: () => ({ blocked, failed }) };
}

test('rapid swipes pause the old owner and ignore its late play rejection', async () => {
  const old = setup(), next = setup();
  old.controller.update(active);
  old.controller.update({ ...active, selected: false });
  next.controller.update(active);
  old.pending[0].reject(new Error('late network failure'));
  await tick();
  assert.equal(old.video.paused, true);
  assert.equal(next.video.paused, false);
  assert.deepEqual(old.errors(), { blocked: 0, failed: 0 });
});

test('autoplay denial offers a gesture; interrupted play does not report a dead URL', async () => {
  const s = setup();
  s.controller.update(active);
  s.pending[0].reject({ name: 'NotAllowedError' });
  await tick();
  assert.deepEqual(s.errors(), { blocked: 1, failed: 0 });
  s.controller.update(active);
  s.pending[1].reject({ name: 'AbortError' });
  await tick();
  assert.deepEqual(s.errors(), { blocked: 1, failed: 0 });
});

test('a current media failure offers retry and disposal ignores all late callbacks', async () => {
  const s = setup();
  s.controller.update(active);
  s.pending[0].reject(new Error('missing media'));
  await tick();
  assert.deepEqual(s.errors(), { blocked: 0, failed: 1 });
  s.controller.update(active);
  s.controller.dispose();
  s.pending[1].reject(new Error('late'));
  await tick();
  assert.equal(s.video.paused, true);
  assert.deepEqual(s.errors(), { blocked: 0, failed: 1 });
});

test('background recovery preserves a manual pause and selected-only scrubbing', () => {
  const s = setup();
  s.controller.update(active);
  s.controller.update({ ...active, foreground: false });
  assert.equal(s.video.paused, true);
  s.controller.update({ ...active, foreground: true, paused: true });
  assert.equal(s.video.paused, true);
  s.controller.update({ ...active, scrubbing: true });
  s.controller.seek(8);
  assert.equal(s.video.currentTime, 8);
  assert.equal(s.video.paused, true);
  s.controller.update({ ...active, selected: false });
  assert.equal(s.video.paused, true);
  s.controller.update(active);
  assert.equal(s.video.paused, false);
});

test('seeking clamps to real duration and rejects non-finite metadata', () => {
  const s = setup();
  s.controller.seek(999); assert.equal(s.video.currentTime, 12);
  s.controller.seek(-8); assert.equal(s.video.currentTime, 0);
  s.video.duration = NaN; s.controller.seek(8); assert.equal(s.video.currentTime, 0);
});

test('finished final reel stays paused through background recovery until explicit replay', () => {
  const s = setup();
  s.controller.update(active);
  s.controller.update({ ...active, ended: true });
  s.controller.update({ ...active, foreground: false, ended: true });
  s.controller.update({ ...active, foreground: true, ended: true });
  assert.equal(s.video.paused, true);
  assert.equal(s.controller.canAdvance(), false);
  s.controller.seek(0);
  s.controller.update({ ...active, ended: false });
  assert.equal(s.video.paused, false);
  s.controller.update({ ...active, scrubbing: true });
  assert.equal(s.controller.canAdvance(), false);
});

test('refresh discards stale pages without cancelling the new request', () => {
  const cursor = new DiscoverPageCursor();
  const old = cursor.begin();
  assert.equal(cursor.begin(), null);
  cursor.reset();
  const fresh = cursor.begin();
  assert.equal(cursor.complete(old), false);
  cursor.fail(old);
  assert.equal(cursor.begin(), null);
  assert.equal(cursor.complete(fresh), true);
  assert.equal(cursor.begin().page, 3);
});

test('late page arrival advances only the same selected reel, with duplicate IDs removed', () => {
  const clips = mergeClipPage([{ id: '1' }, { id: 2 }], [{ id: '2' }, { id: '3' }, { id: '3' }]);
  assert.deepEqual(clips.map((c) => String(c.id)), ['1', '2', '3']);
  assert.equal(nextClipIndex(['1', '2'], '2', '2'), null);
  assert.equal(nextClipIndex(['1', '2', '3'], '2', '2'), 2);
  assert.equal(nextClipIndex(['1', '2', '3'], '3', '2'), null);
});
