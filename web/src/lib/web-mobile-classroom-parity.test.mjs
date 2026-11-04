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
  assert.match(classroom, /const nextAction = classroomNextAction/);
  assert.match(classroom, /disabled=\{nextAction.disabled\}/);
  assert.match(classroom, /case 'continue': continueLesson\(\); break;/);
  assert.match(classroom, /aria-label="Classroom step navigation"/);
});

test('Web mobile hides its dock while Live or Classroom owns the screen', () => {
  assert.match(nav, /voiceSessionActive \|\| isActiveHref\('\/classroom'/);
  assert.match(nav, /h-\[72px\]/);
  assert.match(live, /lyo-live-magic__main/);
  assert.match(live, /lyo-live-magic__composer/);
});


test('short-screen mode picker scrolls choices independently of the always-visible action', () => {
  assert.ok(classroom.includes('data-classroom-mode-options'));
  assert.ok(classroom.includes('data-classroom-mode-footer'));
  assert.ok(classroom.includes('min-h-0 flex-1 flex-col gap-2.5 overflow-y-auto'));
  assert.ok(!classroom.includes('sticky bottom-0 mt-auto rounded-2xl'));
});

test('web Classroom renders teacher prompts using the same math-aware component as the board', () => {
  const board = readFileSync(new URL('../components/classroom/BoardElementView.tsx', import.meta.url), 'utf8');
  const rich = readFileSync(new URL('../components/classroom/ClassroomRichText.tsx', import.meta.url), 'utf8');
  assert.ok(classroom.includes('ClassroomRichText text={prompt.text}'));
  assert.ok(board.includes('ClassroomRichText text={quiz.question'));
  assert.ok(board.includes('ClassroomRichText text={opt.label}'));
  assert.ok(board.includes('ClassroomRichText text={el.feedback}'));
  assert.ok(rich.includes('remarkMath'));
  assert.ok(rich.includes('rehypeKatex'));
  assert.ok(rich.includes('katex-display'));
});
