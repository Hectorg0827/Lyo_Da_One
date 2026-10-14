import test from 'node:test';
import assert from 'node:assert/strict';
import { joinSpoken, spokenPrefix } from './voice-reveal.mjs';

test('words appear as playback reaches them', () => {
  const segment = 'the mitochondria is the powerhouse';
  assert.equal(spokenPrefix(segment, 0), '');
  assert.equal(spokenPrefix(segment, 0.2), 'the');
  assert.equal(spokenPrefix(segment, 0.5), 'the mitochondria is');
  assert.equal(spokenPrefix(segment, 1), segment);
});

test('a segment being read is never shown as empty', () => {
  // Playback has audibly started, so at least the first word is out loud.
  assert.equal(spokenPrefix('hello there friend', 0.01), 'hello');
});

test('the reveal never runs past the segment', () => {
  assert.equal(spokenPrefix('two words', 5), 'two words');
  assert.equal(spokenPrefix('two words', -1), '');
  assert.equal(spokenPrefix('two words', Number.NaN), '');
});

test('nothing to say reveals nothing', () => {
  assert.equal(spokenPrefix('', 1), '');
  assert.equal(spokenPrefix(null, 1), '');
  assert.equal(spokenPrefix('   ', 1), '');
});

test('each segment continues the answer rather than replacing it', () => {
  assert.equal(joinSpoken('First sentence.', 'Second'), 'First sentence. Second');
  assert.equal(joinSpoken('', 'opening words'), 'opening words');
  assert.equal(joinSpoken('already said', ''), 'already said');
  assert.equal(joinSpoken('  spaced  ', '  out  '), 'spaced out');
});

test('an answer read end to end reads exactly as written', () => {
  const segments = ['Water boils at one hundred degrees.', 'That is at sea level.'];
  let spoken = '';
  for (const segment of segments) spoken = joinSpoken(spoken, spokenPrefix(segment, 1));
  assert.equal(spoken, segments.join(' '));
});
