import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (relative) =>
  readFileSync(new URL(relative, import.meta.url), 'utf8');

const card = read('../components/chat/CourseGenerationCard.tsx');
const chat = read('../components/chat/ChatInterface.tsx');
const input = read('../components/chat/ChatInputBar.tsx');
const store = read('../stores/chat-store.ts');
const api = read('./api.ts');

test('course generation has one visible progress surface', () => {
  assert.doesNotMatch(card, /GENERATION_STEPS/);
  assert.match(card, /role="progressbar"/);
  assert.match(chat, /generationActivity !== 'course'/);
  assert.match(chat, /generationProgress > 0/);
});

test('the course card exposes the interpreted course and an adjust action', () => {
  assert.match(card, /Creating your course/);
  assert.match(card, /\bAdjust\b/);
  assert.match(card, /Course outline/);
  assert.match(card, /Apply changes/);
  assert.match(card, /Teaching style/);
  assert.match(card, /Course settings updated/);
  assert.match(card, /\bUndo\b/);
});

test('internal proactive context is never used as a visible course title', () => {
  assert.match(card, /hasInternalPromptText/);
  assert.match(card, /proactive\\s\+\(context\|system\|nudge\)/);
  assert.match(card, /Creating your course…/);
});

test('learners can revise a live course from the composer', () => {
  assert.match(input, /isCourseAdjustable/);
  assert.match(input, /Adjust the course while it builds/);
  assert.match(input, /reviseActiveCourse\(trimmed\)/);
  assert.match(input, /isGenerating && !isCourseAdjustable/);
});

test('course revisions cancel the old stream and force course routing', () => {
  assert.match(store, /activeStreamController\.abort\(\)/);
  assert.match(store, /forcedIntent: 'COURSE'/);
  assert.match(store, /undoCourseRevision/);
  assert.match(api, /forced_intent: forcedIntent/);
});

test('server course progress events drive the card instead of synthetic increments', () => {
  assert.match(store, /chunk\.type === 'course_generation'/);
  assert.match(store, /chunk\.completed_lessons/);
  assert.match(store, /chunk\.total_lessons/);
  assert.match(store, /generationActivity: 'course'/);
  assert.match(store, /s\.generationActivity === 'course'[\s\S]*?s\.generationProgress/);
});

test('the provisional course card does not masquerade as completed work', () => {
  assert.match(store, /const isPreview = chunk\.preview === true/);
  assert.match(store, /generationProgress: isPreview/);
  assert.match(store, /courseGenerationState: isPreview/);
});
