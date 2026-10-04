import test from 'node:test';
import assert from 'node:assert/strict';

import {
  ACTION_RESUME,
  ACTION_REVIEW,
  ACTION_START,
  BLURB_DESCRIPTION,
  BLURB_NONE,
  BLURB_STATUS,
  DECK_PEEK_LIMIT,
  FILTER_ALL,
  FILTER_FINISHED,
  FILTER_IN_PROGRESS,
  FILTER_NOT_STARTED,
  PROGRESS_MEASURED,
  PROGRESS_UNKNOWN,
  actionFor,
  actionLabel,
  blurbFor,
  countForFilter,
  deckLayers,
  deckMoreLabel,
  deckStaggerMilliseconds,
  isFinished,
  matchesFilter,
  motifFor,
  percentFor,
  progressFor,
  stableHash,
} from './focus-presentation.mjs';

const course = (over = {}) => ({
  id: 1,
  title: 'A course',
  item_type: 'course',
  status: 'in_progress',
  progress: 0.4,
  ...over,
});

test('a measured fraction becomes a percentage', () => {
  assert.deepEqual(progressFor(course({ progress: 0.62 })), {
    kind: PROGRESS_MEASURED,
    percent: 62,
  });
  assert.equal(percentFor(course({ progress: 0.62 })), 62);
});

test('out-of-range figures are clamped', () => {
  assert.equal(percentFor(course({ progress: 1.8 })), 100);
  assert.equal(percentFor(course({ progress: -0.4 })), 0);
});

test('a missing progress figure is unknown, never zero', () => {
  // The whole point: an absent number must not be drawn as an empty bar,
  // which would assert the learner is at the start of the course.
  for (const absent of [undefined, null, NaN, Infinity, '0.5']) {
    assert.equal(progressFor(course({ progress: absent })).kind, PROGRESS_UNKNOWN);
    assert.equal(percentFor(course({ progress: absent })), null);
  }
});

test('completion follows the server status, and a missing figure is not finished', () => {
  assert.equal(isFinished(course({ status: 'completed', progress: 0.2 })), true);
  assert.equal(isFinished(course({ status: 'in_progress', progress: 1 })), true);
  assert.equal(isFinished(course({ status: 'in_progress', progress: 0.99 })), false);
  assert.equal(isFinished(course({ status: undefined, progress: undefined })), false);
});

test('the action reflects where the learner is', () => {
  assert.equal(actionFor(course({ status: 'not_started', progress: 0 })), ACTION_START);
  assert.equal(actionFor(course({ status: 'in_progress', progress: 0.4 })), ACTION_RESUME);
  assert.equal(actionFor(course({ status: 'paused', progress: 0.4 })), ACTION_RESUME);
  assert.equal(actionFor(course({ status: 'completed' })), ACTION_REVIEW);
});

test('an unmeasured course offers Start without asserting zero', () => {
  const item = course({ status: undefined, progress: undefined });
  assert.equal(actionFor(item), ACTION_START);
  assert.equal(progressFor(item).kind, PROGRESS_UNKNOWN);
});

test('action labels', () => {
  assert.equal(actionLabel(ACTION_START), 'Start');
  assert.equal(actionLabel(ACTION_RESUME), 'Resume');
  assert.equal(actionLabel(ACTION_REVIEW), 'Review');
});

test('the description the backend sends wins', () => {
  assert.deepEqual(blurbFor(course({ description: 'Vector spaces before matrices.' })), {
    kind: BLURB_DESCRIPTION,
    text: 'Vector spaces before matrices.',
  });
});

test('a description is trimmed, and a blank one counts as absent', () => {
  assert.deepEqual(blurbFor(course({ description: '  Convergence tests.\n' })), {
    kind: BLURB_DESCRIPTION,
    text: 'Convergence tests.',
  });
  // Blank falls through to where the course stands, not to empty prose.
  assert.deepEqual(blurbFor(course({ description: '   ', status: 'paused' })), {
    kind: BLURB_STATUS,
    text: 'Paused',
  });
});

test('with neither a description nor a status the card says nothing rather than filling the space', () => {
  assert.deepEqual(blurbFor({ title: 'x' }), { kind: BLURB_NONE });
});

test('each filter catches what it says', () => {
  const started = course({ status: 'in_progress', progress: 0.5 });
  const fresh = course({ status: 'not_started', progress: 0 });
  const done = course({ status: 'completed', progress: 1 });

  assert.equal(matchesFilter(started, FILTER_IN_PROGRESS), true);
  assert.equal(matchesFilter(started, FILTER_NOT_STARTED), false);
  assert.equal(matchesFilter(started, FILTER_FINISHED), false);
  assert.equal(matchesFilter(fresh, FILTER_NOT_STARTED), true);
  assert.equal(matchesFilter(done, FILTER_FINISHED), true);
  assert.equal(matchesFilter(done, FILTER_IN_PROGRESS), false);
  for (const item of [started, fresh, done]) {
    assert.equal(matchesFilter(item, FILTER_ALL), true);
  }
  assert.equal(countForFilter([started, fresh, done], FILTER_ALL), 3);
  assert.equal(countForFilter([started, fresh, done], FILTER_FINISHED), 1);
});

test('an unmeasured course stays reachable from a filter', () => {
  const unknown = course({ status: undefined, progress: undefined });
  assert.equal(matchesFilter(unknown, FILTER_NOT_STARTED), true);
  assert.equal(matchesFilter(unknown, FILTER_ALL), true);
});

test('subject keywords pick the matching motif', () => {
  assert.equal(motifFor('Organic Chemistry: Reaction Mechanisms'), 'lattice');
  assert.equal(motifFor('Spanish B1 Conversation'), 'speech');
  assert.equal(motifFor('Introduction to Statistics'), 'curve');
  assert.equal(motifFor('Music Theory Basics'), 'staff');
  assert.equal(motifFor('Linear Algebra Done Right'), 'grid');
  assert.equal(motifFor('ORGANIC CHEMISTRY'), 'lattice');
});

test('the artwork is the same every visit', () => {
  // Rules out any hash seeded per process or per page load: a course that
  // repainted itself on reload would look broken rather than generated.
  assert.equal(motifFor('Beekeeping for beginners'), motifFor('Beekeeping for beginners'));
  assert.notEqual(stableHash('one'), stableHash('two'));
  assert.equal(stableHash('one'), stableHash('one'));
});

test('iOS and web choose the same motif for the same course', () => {
  // Golden values computed from Swift's `FocusPresentation.stableHash`
  // (UInt64 FNV-1a over the lowercased title, indexed into FocusArtMotif
  // .allCases). If either platform's hash or motif order changes, the same
  // course starts looking different on each, and this fails.
  const shared = {
    'Beekeeping for beginners': 'grid',
    Woodworking: 'speech',
    'Chess openings': 'lattice',
    'Ancient Rome': 'curve',
    '': 'orbit',
  };
  for (const [title, motif] of Object.entries(shared)) {
    assert.equal(motifFor(title), motif, `motif drifted for ${JSON.stringify(title)}`);
  }
});

// ── The deck ──────────────────────────────────────────────────────────────
//
// Three platforms draw the collapsed deck from the same table, so these
// values are a cross-platform contract: the matching Swift and Kotlin suites
// assert the same numbers.

test('a single course has no deck to open', () => {
  assert.deepEqual(deckLayers(1), []);
  assert.equal(deckMoreLabel(1), null);
  assert.deepEqual(deckLayers(0), []);
  assert.equal(deckMoreLabel(0), null);
});

test('two courses draw one peek card, three draw two', () => {
  assert.deepEqual(deckLayers(2), [{ depth: 1, offset: 11, scale: 0.95, opacity: 0.72 }]);
  assert.deepEqual(deckLayers(3), [
    { depth: 1, offset: 11, scale: 0.95, opacity: 0.72 },
    { depth: 2, offset: 20, scale: 0.9, opacity: 0.46 },
  ]);
});

test('the deck stops at two peek cards however many courses are saved', () => {
  assert.equal(deckLayers(4).length, 2);
  assert.equal(deckLayers(40).length, 2);
  assert.equal(DECK_PEEK_LIMIT, 2);
});

test('the label counts every hidden course, not just the ones drawn', () => {
  // A deck drawing two layers over twelve courses still says eleven are
  // waiting: the figure belongs to the learner's library, not to the artwork.
  assert.equal(deckMoreLabel(2), '1 more course');
  assert.equal(deckMoreLabel(3), '2 more courses');
  assert.equal(deckMoreLabel(12), '11 more courses');
});

test('the stagger starts at zero, steps, and then stops', () => {
  assert.equal(deckStaggerMilliseconds(0), 0);
  assert.equal(deckStaggerMilliseconds(-3), 0);
  assert.equal(deckStaggerMilliseconds(1), 35);
  assert.equal(deckStaggerMilliseconds(3), 105);
  assert.equal(deckStaggerMilliseconds(8), 280);
  // Capped: forty saved courses must not mean a 1.4s wait for the list.
  assert.equal(deckStaggerMilliseconds(40), 280);
});
