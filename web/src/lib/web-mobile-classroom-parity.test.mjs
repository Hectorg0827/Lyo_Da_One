import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const classroom = readFileSync(new URL('../app/(main)/classroom/page.tsx', import.meta.url), 'utf8');
const nav = readFileSync(new URL('../components/layout/MobileNav.tsx', import.meta.url), 'utf8');
const live = readFileSync(new URL('../components/chat/ConversationalVoiceLayer.tsx', import.meta.url), 'utf8');

test('Classroom exposes Focus, Live Class and Review & Resume with a mobile-safe Start control', () => {
  for (const label of ['Focus Mode', 'Live Class', 'Review & Resume', 'Start lesson']) {
    assert.ok(classroom.includes(label), `Missing classroom mode or action: ${label}`);
  }
  assert.match(classroom, /role="dialog" aria-modal="true"/);
  assert.match(classroom, /env\(safe-area-inset-bottom\)/);
});

test('Classroom mode switching is a presentation change after the lesson starts', () => {
  assert.match(classroom, /if \(!hasStarted\) \{/);
  assert.match(classroom, /setMode\(selected === 'live' \? 'classroom' : 'solo'\)/);
  assert.match(classroom, /setDisplayMode\(selected\)/);
  assert.match(classroom, /viewBoard\(totalBoards - 1\)/);
  assert.match(classroom, /if \(!hasStarted\) return;/);
});

test('Step navigation never skips a live answer checkpoint', () => {
  assert.match(classroom, /const canAdvanceStep = viewingBoard !== -1 \|\| readyToContinue/);
  assert.match(classroom, /disabled=\{!canAdvanceStep\}/);
  assert.match(classroom, /if \(readyToContinue\) continueLesson\(\)/);
  assert.match(classroom, /aria-label="Classroom step navigation"/);
});

test('Web mobile hides its dock while Live or Classroom owns the screen', () => {
  assert.match(nav, /voiceSessionActive \|\| isActiveHref\('\/classroom'/);
  assert.match(nav, /h-\[72px\]/);
  assert.match(live, /lyo-live-magic__main/);
  assert.match(live, /lyo-live-magic__composer/);
});
