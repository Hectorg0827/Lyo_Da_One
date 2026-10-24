import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DECISION_MESSAGES, MODERATION_VIEWS, actionsFor, belongsIn, reasonLabel, statusLabel } from './moderation.mjs';

const API_REASONS = [
  'spam', 'harassment', 'hate_speech', 'violence', 'sexual_content',
  'misinformation', 'impersonation', 'copyright', 'inappropriate', 'other',
];

test('the three views are the ones the API lists', () => {
  assert.deepEqual(MODERATION_VIEWS.map((view) => view.id), ['reported', 'all', 'removed']);
  for (const view of MODERATION_VIEWS) assert.ok(view.label && view.empty);
});

test('every reason the API stores reads as words', () => {
  for (const reason of API_REASONS) assert.notEqual(reasonLabel(reason), reason, reason);
  assert.equal(reasonLabel('misinformation'), 'Wrong or false science');
});

test('Keep is offered only when there is something to clear', () => {
  assert.deepEqual(actionsFor({ moderationStatus: 'hidden', reports: { pending: 3 } }), ['keep', 'remove']);
  assert.deepEqual(actionsFor({ moderationStatus: 'active', reports: { pending: 1 } }), ['keep', 'remove']);
  assert.deepEqual(actionsFor({ moderationStatus: 'active', reports: { pending: 0 } }), ['remove']);
  assert.deepEqual(actionsFor({ moderationStatus: 'removed', reports: { pending: 0 } }), ['restore']);
  assert.equal(statusLabel('hidden'), 'Hidden until you decide');
  assert.ok(DECISION_MESSAGES.remove.includes('offline'));
});

test('after a decision a video stays only in the view it still belongs to', () => {
  const kept = { moderationStatus: 'active', reports: { pending: 0 } };
  const removed = { moderationStatus: 'removed', reports: { pending: 0 } };
  assert.equal(belongsIn('reported', kept), false);
  assert.equal(belongsIn('all', kept), true);
  assert.equal(belongsIn('all', removed), false);
  assert.equal(belongsIn('removed', removed), true);
  assert.equal(belongsIn('removed', kept), false);
});

test('the page asks the API who may use it, confirms Remove, and links from Settings', () => {
  const page = readFileSync(new URL('../app/(main)/moderation/page.tsx', import.meta.url), 'utf8');
  const settings = readFileSync(new URL('../app/(main)/settings/page.tsx', import.meta.url), 'utf8');
  assert.match(page, /api\.moderation\s*\.me\(\)/);
  assert.ok(page.includes('This page is for moderators'));
  assert.ok(page.includes("onDecide(clip, 'remove', note.trim())"), 'Remove goes through the confirm form');
  assert.ok(page.includes('pagesToFetch(nextPage, decidedSinceLoad.current, 20)'));
  assert.ok(settings.includes('href="/moderation"') && settings.includes('{moderator && ('));
});

test('decisions and list loads cannot overwrite each other, and a failed check is not a denial', () => {
  const page = readFileSync(new URL('../app/(main)/moderation/page.tsx', import.meta.url), 'utf8');
  const api = readFileSync(new URL('./api.ts', import.meta.url), 'utf8');
  assert.ok(page.includes("Couldn&apos;t check your access"), 'an access-check failure has its own state');
  assert.ok(api.includes("request<{ moderator: boolean }>('/api/v1/moderation/me', { signal: AbortSignal.timeout(15000) })"));
  assert.ok(page.includes('busy={busyIds.has(clip.id)}'), 'each card tracks its own pending decision');
  assert.ok(page.includes('if (listVersion.current === startedIn) {'), 'a decision only edits the list it was made in');
  assert.ok(page.includes('clips.length === 0 && total > 0 && decidedSinceLoad.current > 0'), 'an emptied list refills');
});
