import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../stores/classroom-store.ts', import.meta.url), 'utf8');

function codeBetween(start, end) {
  const left = source.indexOf(start);
  const right = source.indexOf(end, left);
  assert.ok(left >= 0 && right > left, 'Classroom event contract markers must exist');
  return source.slice(left, right);
}

test('temporary teacher cannot disarm the authoritative lesson wait watchdog', () => {
  const handler = codeBetween("case 'bridge_message': {", "case 'answer_feedback': {");
  const speech = codeBetween('function enqueueBridgeSpeech(', '// The answer-feedback event');
  assert.match(handler, /enqueueBridgeSpeech\(text\)/);
  assert.doesNotMatch(handler, /enqueueTurns\(/);
  assert.doesNotMatch(speech, /waitingForScene\s*:/);
  assert.doesNotMatch(speech, /waitingSince\s*=/);
  assert.doesNotMatch(speech, /stallPhase\s*:/);
  assert.doesNotMatch(speech, /recordResponseLatency\(/);
  assert.match(speech, /turnQueue\.push\(/);
  assert.match(speech, /resumePlayer\(\)/);
});

test('real teaching preempts bridge even when only a component render arrives', () => {
  const handler = codeBetween("case 'component_render': {", "case 'scene_start':");
  assert.match(handler, /bridgeClosed\s*=\s*true/);
  assert.match(handler, /stopPlayer\(\)/);
  assert.match(handler, /bridge:\s*null/);
  assert.match(handler, /handleComponent\(comp\)/);
});

test('authoritative scene preempts any queued or playing bridge narration', () => {
  const handler = codeBetween("case 'scene_start':", "case 'scene_complete':");
  assert.match(handler, /bridgeClosed\s*=\s*true/);
  assert.match(handler, /stopPlayer\(\)/);
  assert.match(handler, /turnQueue\s*=\s*\[\]/);
  assert.match(handler, /bridge:\s*null/);
});
