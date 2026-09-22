/**
 * Entry contract — how any surface hands a learner to the Classroom.
 *
 * Home, Chat, Courses and Test Prep all need to open the Classroom, and each
 * one building its own query string is how the four of them drift into
 * teaching slightly different things. The rules live here instead, next to
 * `classroom-contract.mjs`, which owns the wire format once the Classroom is
 * open.
 *
 * `.mjs` so the Node test runner and the cross-platform parity scripts can
 * import it directly, matching classroom-contract.mjs.
 */

import { normalizeClassroomMode } from './classroom-contract.mjs';

/**
 * The opening turn behind Home's "I have a test".
 *
 * Test Prep is a real backend intent (TEST_PREP in lyo_app/ai/router.py),
 * resolved from what the learner says. So the entry actually says it and lets
 * the router ask for subject, date and materials, rather than a client-side
 * mock of a test-prep wizard standing in front of it.
 */
export const TEST_PREP_OPENING_TURN =
  'I have a test coming up and I want to get ready for it.';

/** A default objective, so the Director always receives an intent. */
export function defaultObjective(topic) {
  return `Understand and apply ${topic}`;
}

/**
 * The lesson shape a learner may optionally set before the Classroom opens.
 *
 * Every option here is one the backend actually reads. Nothing is offered
 * that only decorates the form:
 *
 *  - `level` maps to `preferred_difficulty` (0.3 / 0.6 / 0.85) in
 *    `scene_lifecycle_engine.py`, which reaches the teaching prompt as
 *    "level".
 *  - `minutes` maps to `target_duration_minutes`, which the prompt receives as
 *    `target_minutes` and which `unit_count()` turns into how many units get
 *    taught. The server clamps it to 3–60.
 *  - `language` maps to `language_code` via `TTSService.normalize_language`,
 *    which is what the teacher actually speaks.
 *
 * Asking a question whose answer changes nothing would be a worse form than
 * not asking it, so this list and the backend's readers move together.
 */
export const CLASSROOM_LEVELS = [
  { value: 'beginner', label: 'New to this', hint: 'Start from the ground up' },
  { value: 'intermediate', label: 'Some of it', hint: 'Fill the gaps, move quicker' },
  { value: 'advanced', label: 'Most of it', hint: 'Go straight to the hard parts' },
];

/**
 * Session lengths, in minutes.
 *
 * Shared with the Classroom so the two cannot drift. The Classroom only
 * honours a duration it recognises, so a length offered here that it did not
 * accept would silently become 10 — the learner would set 45 minutes and be
 * taught a ten-minute lesson, with nothing on screen admitting it.
 */
export const SESSION_LENGTHS = [5, 10, 20, 30, 45];

/**
 * Languages the teacher can actually be asked for.
 *
 * These are the five families `TTSService.normalize_language` maps to a
 * locale. `auto` is the default and is not a language: it lets the server
 * detect one from the topic itself.
 */
export const CLASSROOM_LANGUAGES = [
  { value: 'auto', label: 'Match my topic' },
  { value: 'en', label: 'English' },
  { value: 'es', label: 'Español' },
  { value: 'fr', label: 'Français' },
  { value: 'it', label: 'Italiano' },
  { value: 'pt', label: 'Português' },
];

/**
 * Keep a value only when it is one we offered.
 *
 * An unrecognised level is dropped rather than guessed at. Sending it on
 * would have the server fall back to its own default anyway, but a dropped
 * parameter and a wrong one read the same in a URL and differently in a
 * lesson.
 */
function knownValue(value, allowed) {
  const clean = (value ?? '').toString().trim().toLowerCase();
  return allowed.includes(clean) ? clean : null;
}

export function normalizeLevel(level) {
  return knownValue(level, CLASSROOM_LEVELS.map((l) => l.value));
}

export function normalizeLanguage(language) {
  const known = knownValue(language, CLASSROOM_LANGUAGES.map((l) => l.value));
  // `auto` is the default the Classroom already applies, so it is carried as
  // nothing rather than as a parameter claiming a choice was made.
  return known === 'auto' ? null : known;
}

export function normalizeSessionMinutes(minutes) {
  const value = Number(minutes);
  return SESSION_LENGTHS.includes(value) ? value : null;
}

/**
 * Open the Classroom on a topic.
 *
 * Returns null for an empty topic: a Classroom with nothing to teach is not a
 * destination, and callers should keep their CTA disabled rather than push an
 * empty session.
 *
 * `level`, `minutes` and `language` are the learner's optional answers. Each
 * is omitted when unset or unrecognised, so an untouched form produces exactly
 * the URL it always did and the Classroom's own defaults still apply.
 */
export function classroomEntryHref({
  topic, mode, objective, courseId, lessonId, level, minutes, language,
} = {}) {
  const cleanTopic = (topic ?? '').trim();
  if (!cleanTopic) return null;

  const params = new URLSearchParams({
    topic: cleanTopic,
    objective: (objective ?? '').trim() || defaultObjective(cleanTopic),
  });

  // Only pin a mode when one was asked for; the Classroom's own default
  // otherwise applies rather than this module second-guessing it.
  if (mode !== undefined) params.set('mode', normalizeClassroomMode(mode));
  if (courseId) params.set('courseId', courseId);
  if (lessonId) params.set('lessonId', lessonId);

  const cleanLevel = normalizeLevel(level);
  if (cleanLevel) params.set('difficulty', cleanLevel);

  const cleanMinutes = normalizeSessionMinutes(minutes);
  if (cleanMinutes) params.set('duration', String(cleanMinutes));

  const cleanLanguage = normalizeLanguage(language);
  if (cleanLanguage) params.set('language', cleanLanguage);

  return `/classroom?${params.toString()}`;
}

/**
 * Open the Classroom in review mode for a concept whose spaced-repetition
 * schedule says it is due.
 *
 * Review mode carries no stored question: retrieval is generated fresh, since
 * replaying the exact question the learner already saw tests recall of that
 * question rather than of the concept.
 */
export function reviewEntryHref(conceptLabel) {
  return classroomEntryHref({
    topic: conceptLabel,
    mode: 'review',
    objective: `Retrieve and re-apply ${(conceptLabel ?? '').trim()}`,
  });
}

/**
 * Open the Classroom to practise a concept the learner is weak on.
 *
 * Deliberately NOT review mode. Review asks the learner to retrieve something
 * they already learned, and a success there is retention evidence. A concept
 * on the weak list has not been learned yet — asking them to retrieve it tests
 * a memory that was never formed, and any success would be recorded as
 * durable recall it is not.
 *
 * So this leaves the mode unset: the Classroom teaches, and the demonstration
 * lands at whatever rung the question actually asks for.
 */
export function practiceEntryHref(conceptLabel) {
  const label = (conceptLabel ?? '').trim();
  return classroomEntryHref({
    topic: label,
    objective: `Practise and apply ${label}`,
  });
}

/** Open the saved account-owned Test Prep workflow. Chat uses its same API. */
export function testPrepEntryHref() {
  return '/test-prep';
}

/**
 * Does Home show the learner dashboard (greeting, hero card, stats grid), or
 * lead with the front door alone?
 *
 * The subtle case is the one before auth resolves. `isLoading` starts true, so
 * treating "still loading" as "known learner" renders Level 1 / 0 XP /
 * 0 courses to a signed-out visitor for as long as the auth request takes —
 * which is precisely the zero dashboard the front door exists to replace, just
 * briefer. Withholding it instead costs a signed-in learner a moment before
 * their own work appears. That is a progressive load, not a false claim about
 * them, so it is the right way to be wrong while we do not yet know who is
 * looking.
 *
 * The front door itself renders either way, so nobody is left with an empty
 * screen while this resolves.
 */
export function shouldShowLearnerDashboard({
  authLoading,
  isAuthenticated,
  hasRealActivity,
} = {}) {
  if (authLoading) return false;
  return Boolean(isAuthenticated && hasRealActivity);
}
