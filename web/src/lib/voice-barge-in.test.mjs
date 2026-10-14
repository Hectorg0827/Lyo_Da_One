import test from 'node:test';
import assert from 'node:assert/strict';
import { shouldEndTurnOnSpeech } from './voice-barge-in.mjs';

test('an echo of Lyo never ends its turn', () => {
  for (const monitorState of ['ready', 'pending', 'unavailable']) {
    assert.equal(
      shouldEndTurnOnSpeech({ isEcho: true, loudEnough: true, monitorState }),
      false,
    );
  }
});

test('words Lyo did not say still do not end its turn on their own', () => {
  // Speaker bleed is distorted, so the engine returns words that are in no
  // echo of the answer. This is the case that made Lyo interrupt itself.
  assert.equal(
    shouldEndTurnOnSpeech({ isEcho: false, loudEnough: false, monitorState: 'ready' }),
    false,
  );
});

test('speech louder than Lyo ends the turn', () => {
  assert.equal(
    shouldEndTurnOnSpeech({ isEcho: false, loudEnough: true, monitorState: 'ready' }),
    true,
  );
});

test('the turn is held while the monitor is still being granted the mic', () => {
  // Playback has just begun, which is when Lyo is most likely to hear itself.
  assert.equal(
    shouldEndTurnOnSpeech({ isEcho: false, loudEnough: false, monitorState: 'pending' }),
    false,
  );
  assert.equal(
    shouldEndTurnOnSpeech({ isEcho: false, loudEnough: true, monitorState: 'pending' }),
    true,
  );
});

test('without a monitor at all, words are enough', () => {
  // Refused or unsupported: barge-in must keep working on what is left.
  assert.equal(
    shouldEndTurnOnSpeech({ isEcho: false, loudEnough: false, monitorState: 'unavailable' }),
    true,
  );
});

test('a missing decision is not an interruption', () => {
  assert.equal(shouldEndTurnOnSpeech(), false);
  assert.equal(shouldEndTurnOnSpeech({}), false);
});
