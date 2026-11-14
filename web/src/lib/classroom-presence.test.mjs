import test from 'node:test';
import assert from 'node:assert/strict';
import { WAITING_COMPANION_BEATS, teacherPresenceMs } from './classroom-presence.mjs';

test('Lyo appears in brief, distinct beats during a long wait', () => {
  assert.equal(WAITING_COMPANION_BEATS.length, 3);
  assert.ok(WAITING_COMPANION_BEATS[0].showAtMs > 0);
  for (let i = 0; i < WAITING_COMPANION_BEATS.length; i++) {
    const beat = WAITING_COMPANION_BEATS[i];
    assert.ok(beat.hideAtMs > beat.showAtMs);
    assert.ok(beat.hideAtMs - beat.showAtMs < 5000);
    assert.ok(beat.cue.length > 15);
    if (i > 0) assert.ok(beat.showAtMs > WAITING_COMPANION_BEATS[i - 1].hideAtMs);
  }
});

test('even a long narration does not pin the teacher portrait to the board', () => {
  assert.ok(teacherPresenceMs({ narrating: true }) < 8000);
  assert.ok(teacherPresenceMs({ prompt: true }) < 5000);
  assert.ok(teacherPresenceMs() < teacherPresenceMs({ narrating: true }));
});
