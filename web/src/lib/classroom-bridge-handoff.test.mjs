import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../stores/classroom-store.ts', import.meta.url), 'utf8');

function segment(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing bounded classroom section: ${start}`);
  return source.slice(a, b);
}

test('ungraded bridge does not disarm canonical lesson watchdog', () => {
  const handler = segment("case 'bridge_message': {", "case 'answer_feedback': {");
  const voice = segment('function enqueueBridgeSpeech(', 'let bridgeClosed = false;');
  assert.match(handler, /enqueueBridgeSpeech\(text\)/);
  assert.match(handler, /data\.ungraded\s*!==\s*true/);
  assert.doesNotMatch(handler, /enqueueTurns\(/);
  assert.doesNotMatch(voice, /waitingForScene\s*:/);
  assert.doesNotMatch(voice, /waitingSince\s*=/);
  assert.doesNotMatch(voice, /stallPhase\s*:/);
  assert.match(voice, /turnQueue\.push\(/);
});

test('real components preempt the temporary teacher', () => {
  const handler = segment("case 'component_render': {", "case 'scene_start':");
  assert.match(handler, /bridgeClosed\s*=\s*true/);
  assert.match(handler, /stopPlayer\(\)/);
  assert.match(handler, /bridge:\s*null/);
});

test('real scenes clear bridge speech and restore canonical scene handling', () => {
  const handler = segment("case 'scene_start':", "case 'scene_complete':");
  assert.match(handler, /bridgeClosed\s*=\s*true/);
  assert.match(handler, /stopPlayer\(\)/);
  assert.match(handler, /turnQueue\s*=\s*\[\]/);
  assert.match(handler, /bridge:\s*null/);
});
