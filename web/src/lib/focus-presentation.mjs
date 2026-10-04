// What the Home page is allowed to say about a learner's saved courses.
//
// Pure functions, no React and no fetch, for the same reason
// `test-prep.mjs` and `learner-model.mjs` exist beside this file: these are
// the decisions that decide whether the page reports something nothing
// measured, and a decision buried in JSX cannot be unit-tested, while this
// can. iOS keeps the same rules in `FocusPresentation.swift`.
//
// The rule underneath all of them: a figure the app does not have is not a
// zero, and an action label is not a measurement.

/** A real 0–100 figure. */
export const PROGRESS_MEASURED = 'measured';
/** Nothing usable to draw. Not zero. */
export const PROGRESS_UNKNOWN = 'unknown';

export const ACTION_START = 'start';
export const ACTION_RESUME = 'resume';
export const ACTION_REVIEW = 'review';

export const BLURB_DESCRIPTION = 'description';
export const BLURB_STATUS = 'status';
export const BLURB_NONE = 'none';

export const FILTER_ALL = 'all';
export const FILTER_IN_PROGRESS = 'in_progress';
export const FILTER_NOT_STARTED = 'not_started';
export const FILTER_FINISHED = 'finished';

export const FILTERS = Object.freeze([
  { id: FILTER_ALL, label: 'All' },
  { id: FILTER_IN_PROGRESS, label: 'In progress' },
  { id: FILTER_NOT_STARTED, label: 'Not started' },
  { id: FILTER_FINISHED, label: 'Finished' },
]);

/** The motifs a course's generated artwork can draw. Same list as iOS. */
export const MOTIFS = Object.freeze([
  'lattice', // bonds and rings — chemistry, biology, physical sciences
  'speech',  // arcs and a waveform — languages, conversation
  'curve',   // a distribution and scatter — statistics, data
  'staff',   // staves and noteheads — music
  'grid',    // axes and vectors — algebra, calculus, geometry
  'orbit',   // concentric paths — everything else
]);

/**
 * How far through a course the learner is, or why there is no answer.
 *
 * The server sends `progress` as a 0–1 fraction. A value that is absent or
 * not a finite number is unknown rather than zero: the page must not draw an
 * empty bar and thereby assert the learner is at the start of a course whose
 * progress simply failed to arrive.
 */
export function progressFor(item) {
  const raw = item?.progress;
  if (typeof raw !== 'number' || !Number.isFinite(raw)) {
    return { kind: PROGRESS_UNKNOWN };
  }
  const clamped = Math.min(Math.max(raw, 0), 1);
  return { kind: PROGRESS_MEASURED, percent: Math.round(clamped * 100) };
}

/** The percentage, or null when there is none to give. Never 0 as a stand-in. */
export function percentFor(item) {
  const progress = progressFor(item);
  return progress.kind === PROGRESS_MEASURED ? progress.percent : null;
}

/**
 * Has the learner finished this course?
 *
 * `status` is the server's own word and it is derived server-side from the
 * same progress figure (see the PUT handler described in lib/stack.ts), so it
 * is preferred over re-deriving the answer from the number here.
 */
export function isFinished(item) {
  if (item?.status === 'completed') return true;
  const progress = progressFor(item);
  return progress.kind === PROGRESS_MEASURED && progress.percent >= 100;
}

/**
 * What the card's primary button offers.
 *
 * A label for an action, not a claim about the learner: `start` is what the
 * button says when no progress is recorded, which is not the same as
 * asserting the learner has done nothing.
 */
export function actionFor(item) {
  if (isFinished(item)) return ACTION_REVIEW;
  if (item?.status === 'in_progress' || item?.status === 'paused') return ACTION_RESUME;
  if (item?.status === 'not_started') return ACTION_START;
  const progress = progressFor(item);
  if (progress.kind === PROGRESS_MEASURED && progress.percent > 0) return ACTION_RESUME;
  return ACTION_START;
}

export function actionLabel(action) {
  if (action === ACTION_RESUME) return 'Resume';
  if (action === ACTION_REVIEW) return 'Review';
  return 'Start';
}

/**
 * What the back of a course card says about the course.
 *
 * `description` comes straight from the stack item the backend already sends
 * and the page previously dropped. When there is none, the card says where
 * the course stands instead of being given prose nothing wrote.
 */
export function blurbFor(item) {
  const description = trimmed(item?.description);
  if (description) return { kind: BLURB_DESCRIPTION, text: description };
  const status = statusLabel(item?.status);
  if (status) return { kind: BLURB_STATUS, text: status };
  return { kind: BLURB_NONE };
}

export function statusLabel(status) {
  if (status === 'not_started') return 'Saved — not started yet';
  if (status === 'in_progress') return 'In progress';
  if (status === 'paused') return 'Paused';
  if (status === 'completed') return 'Finished';
  return null;
}

/** Does this course belong under that filter? */
export function matchesFilter(item, filter) {
  if (filter === FILTER_ALL) return true;
  if (filter === FILTER_FINISHED) return isFinished(item);
  if (isFinished(item)) return false;
  const action = actionFor(item);
  if (filter === FILTER_IN_PROGRESS) return action === ACTION_RESUME;
  if (filter === FILTER_NOT_STARTED) return action === ACTION_START;
  return false;
}

export function countForFilter(items, filter) {
  return (items || []).filter((item) => matchesFilter(item, filter)).length;
}

/**
 * Peek cards drawn behind the top one, at most.
 *
 * Two, however many courses are saved: a third layer costs pixels and
 * carries no information, and the real number is written on the control
 * beneath the deck instead.
 */
export const DECK_PEEK_LIMIT = 2;

const DECK_OFFSETS = Object.freeze([11, 20]);
const DECK_SCALES = Object.freeze([0.95, 0.9]);
const DECK_OPACITIES = Object.freeze([0.72, 0.46]);
const DECK_STAGGER_STEP = 35;
const DECK_STAGGER_LIMIT = 8;

/**
 * The cards stacked behind the top of a collapsed deck.
 *
 * The figures are a shared table rather than a formula because iOS, web and
 * Android all draw this deck, and a table is the only version of "11 pixels
 * down, 95% the size" that cannot quietly drift between three codebases.
 * `focus-presentation.test.mjs` pins them, as do the Swift and Kotlin suites.
 *
 * A learner with one saved course gets no layers, so they never have to open
 * anything to reach it.
 */
export function deckLayers(cardCount) {
  const count = Number.isFinite(cardCount) ? Math.trunc(cardCount) : 0;
  if (count <= 1) return [];
  const peek = Math.min(count - 1, DECK_PEEK_LIMIT);
  const layers = [];
  for (let depth = 1; depth <= peek; depth += 1) {
    layers.push({
      depth,
      offset: DECK_OFFSETS[depth - 1],
      scale: DECK_SCALES[depth - 1],
      opacity: DECK_OPACITIES[depth - 1],
    });
  }
  return layers;
}

/**
 * What the control under a collapsed deck says.
 *
 * It counts the courses the deck is really holding back — the list's own
 * length, less the card already on top — and not the peek cards drawn, which
 * stop at two. A deck that drew two layers over twelve courses and said
 * "2 more" would be understating the learner's own library. Returns null when
 * nothing is hidden.
 */
export function deckMoreLabel(cardCount) {
  const count = Number.isFinite(cardCount) ? Math.trunc(cardCount) : 0;
  if (count <= 1) return null;
  const hidden = count - 1;
  return hidden === 1 ? '1 more course' : `${hidden} more courses`;
}

/**
 * How long the card at `index` waits before it slides into place, in ms.
 *
 * Whole milliseconds rather than fractional seconds, so three languages'
 * floating point cannot disagree about the timing. Capped, so a learner with
 * forty saved courses is not watching cards arrive for a second and a half.
 */
export function deckStaggerMilliseconds(index) {
  const position = Number.isFinite(index) ? Math.trunc(index) : 0;
  if (position <= 0) return 0;
  return DECK_STAGGER_STEP * Math.min(position, DECK_STAGGER_LIMIT);
}

/**
 * Which generated motif a course's artwork draws.
 *
 * Subject keywords first, so organic chemistry really does get bonds and
 * Spanish really does get speech arcs, then a deterministic fall-back so two
 * courses rarely look alike and one course never changes its art. Identical
 * to iOS `FocusPresentation.motif(forTitle:)` so the same course is drawn the
 * same way on both platforms.
 */
export function motifFor(title) {
  const text = String(title ?? '').toLowerCase();

  for (const [motif, keywords] of KEYWORD_TABLE) {
    if (keywords.some((keyword) => text.includes(keyword))) return motif;
  }

  const seed = text.length > 0 ? text : 'lyo';
  return MOTIFS[Number(stableHash(seed) % BigInt(MOTIFS.length))];
}

/** Ordered so a title matching more than one table wins the earlier entry. */
const KEYWORD_TABLE = Object.freeze([
  ['lattice', ['chem', 'molecul', 'organic', 'biolog', 'reaction', 'atom', 'physics', 'protein', 'cell']],
  ['speech', ['spanish', 'french', 'german', 'italian', 'portuguese', 'mandarin', 'japanese', 'korean',
    'arabic', 'language', 'conversation', 'grammar', 'vocabular', 'speaking', 'english']],
  ['curve', ['statistic', 'probabilit', 'data', 'regression', 'analytic', 'distribution', 'machine learning']],
  ['staff', ['music', 'piano', 'guitar', 'harmony', 'rhythm', 'composition', 'singing', 'chord']],
  ['grid', ['algebra', 'calculus', 'geometry', 'math', 'matrix', 'vector', 'trigonometr', 'arithmetic',
    'series', 'equation']],
]);

/**
 * FNV-1a, in BigInt so it cannot lose precision.
 *
 * A course's artwork must not change between visits, which rules out any
 * hash seeded per process or per page load. iOS uses the same algorithm over
 * the same lowercased title, so both platforms land on the same motif.
 */
export function stableHash(text) {
  let hash = 0xcbf29ce484222325n;
  const mask = 0xffffffffffffffffn;
  for (const byte of new TextEncoder().encode(String(text ?? ''))) {
    hash ^= BigInt(byte);
    hash = (hash * 0x100000001b3n) & mask;
  }
  return hash;
}

function trimmed(value) {
  if (typeof value !== 'string') return null;
  const text = value.trim();
  return text.length > 0 ? text : null;
}
