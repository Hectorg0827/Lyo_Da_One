import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  REPORT_NOTE_LIMIT, REPORT_REASONS, blockOutcome, canBlock, canReport, pagesToFetch, reportOutcome,
} from './discover-report.mjs';
import { mergeClipPage } from './discover-playback.mjs';

// The reasons POST /api/v1/clips/{id}/report accepts (LyoBackendJune
// lyo_app/community/models.py ReportReason). Anything else is a 422.
const API_REASONS = new Set([
  'spam', 'harassment', 'hate_speech', 'violence', 'sexual_content',
  'misinformation', 'impersonation', 'copyright', 'inappropriate', 'other',
]);

test('every report reason is one the API stores, each offered once', () => {
  for (const { value } of REPORT_REASONS) assert.ok(API_REASONS.has(value), `API refuses ${value}`);
  assert.equal(new Set(REPORT_REASONS.map((r) => r.value)).size, REPORT_REASONS.length);
  assert.equal(new Set(REPORT_REASONS.map((r) => r.label)).size, REPORT_REASONS.length);
  assert.ok(REPORT_REASONS.some((r) => r.value === 'other'), 'a learner can always say "something else"');
  assert.equal(REPORT_NOTE_LIMIT, 1000);
});

test('a learner cannot report their own video, and an unknown owner leaves it to the server', () => {
  assert.equal(canReport('42', '42'), false);
  assert.equal(canReport(42, '42'), false);
  assert.equal(canReport('42', '7'), true);
  assert.equal(canReport(null, '7'), true);
  assert.equal(canReport('42', undefined), true);
});

test('a report, a repeat report or a vanished video leaves the feed; a failure does not', () => {
  assert.deepEqual(reportOutcome(201), { leaveFeed: true, message: "Thanks. We'll review this video." });
  assert.equal(reportOutcome(200).leaveFeed, true);
  assert.equal(reportOutcome(404).leaveFeed, true);
  for (const status of [0, 400, 401, 422, 500, 503]) {
    assert.equal(reportOutcome(status).leaveFeed, false, `status ${status}`);
  }
});

test('Discover offers Report on other people\'s videos and drops a reported one from the feed', () => {
  const page = readFileSync(new URL('../app/(main)/discover/page.tsx', import.meta.url), 'utf8');
  const sheet = readFileSync(new URL('../components/clips/ReportClipSheet.tsx', import.meta.url), 'utf8');
  assert.ok(page.includes('<ActionButton label="Report" onClick={onReport}>'));
  assert.ok(page.includes('onReport={canReport(reel.ownerId, viewerId) ? () => setReportingFor(reel) : undefined}'));
  assert.ok(page.includes('.filter((r) => !reportedIds.has(r.id) && !(r.ownerId && blockedOwners.has(r.ownerId)))'),
    'a reported video, and every video by someone blocked, leaves the feed');
  assert.ok(page.includes('foreground={foreground && !composing && !commentsFor && !reportingFor}'),
    'the video pauses while the report sheet is open');
  assert.ok(sheet.includes('api.clips.report(clipId, reason, note.trim())'));
  assert.ok(sheet.includes('role="dialog"') && sheet.includes('aria-modal="true"'));
});

test('after a report, the next page also asks for the one before, so no video is skipped', () => {
  assert.deepEqual(pagesToFetch(2, 0, 20), [2]);
  assert.deepEqual(pagesToFetch(2, 1, 20), [1, 2]);
  assert.deepEqual(pagesToFetch(3, 20, 20), [2, 3]);
  assert.deepEqual(pagesToFetch(3, 21, 20), [1, 2, 3]);
  assert.deepEqual(pagesToFetch(2, 45, 20), [1, 2]);

  // 25 videos, pages of 10; the learner reports video 4 while on page 1.
  const all = Array.from({ length: 25 }, (_, i) => ({ id: i + 1 }));
  const serverPage = (n, hidden) => all.filter((c) => !hidden.has(c.id)).slice((n - 1) * 10, n * 10);
  let loaded = serverPage(1, new Set());
  const hidden = new Set([4]);
  for (const n of pagesToFetch(2, 1, 10)) loaded = mergeClipPage(loaded, serverPage(n, hidden));
  for (const n of pagesToFetch(3, 1, 10)) loaded = mergeClipPage(loaded, serverPage(n, hidden));
  assert.deepEqual(loaded.map((c) => c.id), all.map((c) => c.id), 'every video arrives once');
});

test('a report that finishes late never closes a newer report sheet', () => {
  const page = readFileSync(new URL('../app/(main)/discover/page.tsx', import.meta.url), 'utf8');
  assert.ok(page.includes('setReportingFor((current) => (current?.id === reportedId ? null : current))'));
  assert.ok(page.includes('pagesToFetch(request.page, removedSinceLoad.current, 20)'));
});

test('Block is offered on someone else\'s video, never on your own or a library video', () => {
  assert.equal(canBlock('42', '7', false), true);
  assert.equal(canBlock(42, '7', false), true);
  assert.equal(canBlock('42', '42', false), false, 'you cannot block yourself');
  assert.equal(canBlock('42', 42, false), false);
  assert.equal(canBlock('42', '7', true), false, 'blocking the library account would empty Discover');
  assert.equal(canBlock(null, '7', false), false);
  assert.equal(canBlock('42', undefined, false), false, 'an unknown viewer might be the owner');
});

test('a block succeeds once the server stores it; anything else keeps the sheet open', () => {
  assert.deepEqual(blockOutcome(201, 'Sam'), {
    blocked: true, message: "Blocked Sam. You won't see each other's videos or comments.",
  });
  assert.equal(blockOutcome(200, 'Sam').blocked, true);
  assert.deepEqual(blockOutcome(404, 'Sam'), { blocked: false, message: 'This account no longer exists.' });
  for (const status of [0, 400, 401, 422, 500]) assert.equal(blockOutcome(status, 'Sam').blocked, false);
});

test('the report sheet offers Block with a confirmation, and Settings lists blocked accounts', () => {
  const page = readFileSync(new URL('../app/(main)/discover/page.tsx', import.meta.url), 'utf8');
  const sheet = readFileSync(new URL('../components/clips/ReportClipSheet.tsx', import.meta.url), 'utf8');
  const settings = readFileSync(new URL('../app/(main)/settings/page.tsx', import.meta.url), 'utf8');
  const blocked = readFileSync(new URL('../components/settings/BlockedAccounts.tsx', import.meta.url), 'utf8');
  assert.ok(page.includes('canBlock(reportingFor.ownerId, viewerId, Boolean(reportingFor.attribution))'));
  assert.ok(page.includes('removedSinceLoad.current += reels.filter((reel) => reel.ownerId === ownerId).length'),
    'every loaded video by the blocked owner counts toward the page overlap');
  assert.ok(sheet.includes('api.blocks.block(owner.id)'));
  const confirmStep = sheet.slice(sheet.indexOf('{confirmingBlock ? ('), sheet.indexOf(') : (', sheet.indexOf('{confirmingBlock ? (')));
  assert.ok(confirmStep.includes('onClick={block}'), 'blocking asks first: the Block button is only in the confirmation');
  assert.equal(sheet.split('onClick={block}').length, 2, 'nothing else blocks without asking');
  assert.ok(settings.includes('<Section title="Blocked accounts">'));
  assert.ok(blocked.includes('api.blocks.unblock(String(account.user_id))'));
});
