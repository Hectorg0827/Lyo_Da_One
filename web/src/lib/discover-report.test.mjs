import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { REPORT_NOTE_LIMIT, REPORT_REASONS, canReport, reportOutcome } from './discover-report.mjs';

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
  assert.ok(page.includes('ordered.filter((r) => !reportedIds.has(r.id))'), 'reported video leaves the feed');
  assert.ok(page.includes('foreground={foreground && !composing && !commentsFor && !reportingFor}'),
    'the video pauses while the report sheet is open');
  assert.ok(sheet.includes('api.clips.report(clipId, reason, note.trim())'));
  assert.ok(sheet.includes('role="dialog"') && sheet.includes('aria-modal="true"'));
});
