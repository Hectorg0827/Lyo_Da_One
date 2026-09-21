/**
 * Canonical learner model — the client's single vocabulary for evidence,
 * mastery and retention.
 *
 * WHY THIS EXISTS
 *
 * Mastery reaches the clients today under three different field names, on two
 * different scales, from four different surfaces:
 *
 *   AnswerCheckResult.mastery        (chat check)
 *   SessionSummarySkill.mastery      (session recap)
 *   DueReviewItem.mastery_level      (spaced repetition)
 *   Flashcard.mastery                (lesson block)
 *
 * The backend stores mastery as a 0..1 float (`LearnerMastery.mastery_level`,
 * `MasteryState.mastery_score` — see `m.mastery_level:.0%` and the `< 0.4` /
 * `>= 0.7` comparisons in lyo_app/predictive and lyo_app/services). At least
 * one renderer assumed 0..100. That kind of mismatch does not throw; it just
 * draws a confident, wrong number. Normalising in one place is the point.
 *
 * This module does NOT introduce a fifth mastery system. It is the client-side
 * vocabulary that existing surfaces adapt onto, and it defers to the server on
 * every question of fact. See docs/CLASSROOM_ARCHITECTURE.md sections 2-3.
 *
 * `.mjs` so the Node test runner and the parity scripts can import it, matching
 * classroom-contract.mjs and entry-contract.mjs.
 */

// ─── Evidence ────────────────────────────────────────────────────────────────

/**
 * The product's evidence ladder, weakest first.
 *
 * Order is meaning, not decoration: `evidenceRank` compares by index, so
 * reordering this array changes what the product considers stronger proof.
 */
export const EVIDENCE_KINDS = Object.freeze([
  'exposure',      // instruction was delivered — no proof of anything
  'recognition',   // picked the right answer in context
  'explanation',   // explained it acceptably
  'application',   // used it on a familiar problem
  'transfer',      // used it in a novel context
  'retention',     // retrieved it after a real interval
]);

/**
 * What the classroom actually puts on the wire.
 *
 * `InputField.evidence_type` in lyo_app/ai_classroom/sdui_models.py is
 * `Literal["explanation", "application", "transfer", "retrieval"]` — narrower
 * than the ladder above, and it says "retrieval" where the product model says
 * "retention".
 *
 * Adapting here rather than renaming the ladder keeps the client honest about
 * the server's vocabulary. `exposure` and `recognition` have no wire value
 * because the classroom never asks for them through an InputField: exposure is
 * implied by delivery, and recognition arrives as a graded quiz answer.
 */
const WIRE_EVIDENCE_TO_KIND = Object.freeze({
  explanation: 'explanation',
  application: 'application',
  transfer: 'transfer',
  retrieval: 'retention',
});

/** Strength of an evidence kind. -1 for anything unrecognised. */
export function evidenceRank(kind) {
  return EVIDENCE_KINDS.indexOf(kind);
}

/**
 * Normalise an evidence type arriving from the server.
 *
 * An unrecognised value is deliberately NOT coerced to something plausible: a
 * new server-side evidence type must not be silently scored as `exposure` (or,
 * worse, as `transfer`). Callers get null and should record the event without
 * advancing mastery.
 */
export function normalizeEvidenceKind(value) {
  if (EVIDENCE_KINDS.includes(value)) return value;
  return WIRE_EVIDENCE_TO_KIND[value] ?? null;
}

/** Is `a` stronger proof than `b`? */
export function isStrongerEvidence(a, b) {
  const rankA = evidenceRank(normalizeEvidenceKind(a));
  const rankB = evidenceRank(normalizeEvidenceKind(b));
  return rankA > rankB;
}

// ─── Mastery states ──────────────────────────────────────────────────────────

export const MASTERY_STATES = Object.freeze([
  'NOT_SEEN',
  'EXPOSED',
  'RECOGNIZED',
  'EXPLAINED',
  'APPLIED',
  'TRANSFERRED',
  'RETAINED',
  'MASTERED',
]);

/** The state each evidence kind, on its own, can justify. */
const STATE_FOR_EVIDENCE = Object.freeze({
  exposure: 'EXPOSED',
  recognition: 'RECOGNIZED',
  explanation: 'EXPLAINED',
  application: 'APPLIED',
  transfer: 'TRANSFERRED',
  retention: 'RETAINED',
});

/**
 * MASTERED is not a high score on one thing. It requires that the learner has
 * used the concept on a familiar problem, used it somewhere new, and still had
 * it after a delay.
 */
const MASTERY_REQUIRES = Object.freeze(['application', 'transfer', 'retention']);

/** Below this, evidence is too weak to count toward MASTERED. */
export const MASTERY_CONFIDENCE_FLOOR = 0.7;

// ─── Scale normalisation ─────────────────────────────────────────────────────

/**
 * Canonical mastery is a 0..1 float, matching the backend.
 *
 * Values above 1 are read as a percentage, which is how the four client field
 * names above have historically disagreed. The ambiguity is real and
 * unresolvable at 1: a bare `1` means fully mastered on either reading, so both
 * give the same answer. Null/undefined/NaN mean "no reading", not zero —
 * "never assessed" and "assessed at zero" are different claims about a learner.
 */
export function normalizeMastery(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  if (value < 0) return 0;
  const asFraction = value > 1 ? value / 100 : value;
  return Math.min(1, asFraction);
}

/** Canonical mastery as a 0..100 integer, for progress bars and labels. */
export function masteryPercent(value) {
  const normalized = normalizeMastery(value);
  return normalized === null ? null : Math.round(normalized * 100);
}

// ─── Confidence ──────────────────────────────────────────────────────────────

/**
 * How much assistance the learner needed, as a damping factor on confidence.
 *
 * Indexed by the hint ladder in classroom-contract.mjs. Asking for help is
 * never failure and never demotes the evidence rung — it means the
 * demonstration proves less about unaided ability, so the confidence attached
 * to it is lower.
 */
const HINT_DAMPING = Object.freeze({
  nudge: 0.9,
  principle: 0.75,
  worked_step: 0.55,
  full_example: 0.35,
  prerequisite: 0.3,
});

export function confidenceAfterHints(baseConfidence, hintLevel) {
  const base = typeof baseConfidence === 'number' && Number.isFinite(baseConfidence)
    ? Math.max(0, Math.min(1, baseConfidence))
    : 0;
  if (!hintLevel) return base;
  return base * (HINT_DAMPING[hintLevel] ?? 1);
}

// ─── Deriving state ──────────────────────────────────────────────────────────

/**
 * Derive a mastery state from the evidence collected for one concept.
 *
 * `evidence` is a list of `{ kind, confidence }`. Anything below the
 * confidence floor still records the rung it reached but cannot contribute to
 * MASTERED — a shaky transfer is a transfer, not proof of durable mastery.
 *
 * This is advisory on the client. The server owns the authoritative
 * `mastery_score`; this exists so a surface can say *why* it is showing what it
 * shows, and so the four surfaces agree on the words.
 */
export function deriveMasteryState(evidence = []) {
  const seen = new Map();

  for (const entry of evidence) {
    const kind = normalizeEvidenceKind(entry?.kind);
    // Unrecognised evidence is recorded by the caller but never advances a
    // rung — see normalizeEvidenceKind.
    if (!kind) continue;
    const confidence = typeof entry?.confidence === 'number' && Number.isFinite(entry.confidence)
      ? Math.max(0, Math.min(1, entry.confidence))
      : 0;
    // Keep the best demonstration of each kind.
    seen.set(kind, Math.max(seen.get(kind) ?? 0, confidence));
  }

  if (seen.size === 0) return 'NOT_SEEN';

  const confident = MASTERY_REQUIRES.every(
    (kind) => (seen.get(kind) ?? 0) >= MASTERY_CONFIDENCE_FLOOR,
  );
  if (confident) return 'MASTERED';

  // Otherwise: the strongest rung actually reached.
  let best = 'NOT_SEEN';
  let bestRank = -1;
  for (const kind of seen.keys()) {
    const rank = evidenceRank(kind);
    if (rank > bestRank) {
      bestRank = rank;
      best = STATE_FOR_EVIDENCE[kind];
    }
  }
  return best;
}

/**
 * How to name a demonstration back to the learner in their own transcript.
 *
 * Falls back to a neutral "Answer" rather than guessing a rung: telling
 * someone they just did a transfer when the component asked for an
 * explanation misreports their own record to them.
 */
export function transcriptLabelFor(evidenceType) {
  const kind = normalizeEvidenceKind(evidenceType);
  switch (kind) {
    case 'explanation': return 'Explanation';
    case 'application': return 'Application';
    case 'transfer': return 'Transfer';
    case 'retention': return 'Recall';
    default: return 'Answer';
  }
}

// ─── Adapters ────────────────────────────────────────────────────────────────

/**
 * Read a graded chat check as evidence.
 *
 * Three rules the product depends on, all enforced here:
 *
 *  - A skipped question is neutral. `bailed_out` yields no evidence at all,
 *    rather than evidence of failure. Not answering is not getting it wrong.
 *  - Correctness comes from the server's `correct` field. The client never
 *    decides it (see docs section 30) — this reads a verdict, it does not
 *    reach one.
 *  - An incorrect answer still produced exposure, and carries the
 *    misconception forward so remediation can target it.
 */
export function evidenceFromAnswerCheck(result, { hintLevel } = {}) {
  if (!result || result.bailed_out) {
    return { evidence: [], misconception: null, skipped: true };
  }

  const misconception = result.misconception ?? null;

  if (!result.correct) {
    return {
      evidence: [{ kind: 'exposure', confidence: 0 }],
      misconception,
      skipped: false,
    };
  }

  // A correct multiple-choice answer is recognition — the weakest positive
  // rung. It is not application and it is certainly not mastery, however
  // confident the score attached to it looks.
  return {
    evidence: [{ kind: 'recognition', confidence: confidenceAfterHints(1, hintLevel) }],
    misconception,
    skipped: false,
  };
}

/**
 * Read a classroom InputField submission as evidence.
 *
 * The component declares what it is asking for via `evidence_type`; the server
 * grades whether it was met. Both are required — a submission the server did
 * not accept is exposure, not the rung the component hoped for.
 */
export function evidenceFromClassroomSubmission(component, { accepted, hintLevel } = {}) {
  const kind = normalizeEvidenceKind(component?.evidence_type);
  if (!kind || !accepted) {
    return { evidence: [{ kind: 'exposure', confidence: 0 }], conceptId: component?.concept_id ?? null };
  }
  return {
    evidence: [{ kind, confidence: confidenceAfterHints(1, hintLevel) }],
    conceptId: component?.concept_id ?? null,
  };
}

/**
 * Read a due-review row as the learner's state for that concept.
 *
 * `days_overdue > 0` means the schedule lapsed; that weakens the retention
 * claim without erasing the mastery the learner previously demonstrated.
 */
export function conceptFromDueReview(item) {
  return {
    conceptId: item?.skill_id ?? null,
    mastery: normalizeMastery(item?.mastery_level),
    misconception: item?.last_misconception ?? null,
    daysOverdue: Math.max(0, Number(item?.days_overdue) || 0),
    dueForRetrieval: true,
  };
}

/**
 * Should Home lead with what the learner knows, or with what they have done?
 *
 * The specification wants concepts learned, mastered and retained in the lead
 * position: XP, hours and streak are real, but they measure attendance, and a
 * learner with a thirty-day streak still cannot tell from that whether they
 * understand anything.
 *
 * The catch is that the concept counts are earned from evidence, and evidence
 * only exists for work done since the learner model started recording it. A
 * learner with a year of XP and no evidence yet would be shown three zeroes —
 * the same fabrication this page was cleaned up to remove, just with a more
 * flattering vocabulary. Leading with an honest "0 mastered" for someone who
 * has demonstrably been learning is a worse lie than leading with their XP.
 *
 * So: lead with concepts once there is at least one to count. Otherwise show
 * the activity stats, which are at least true.
 */
export function shouldLeadWithConcepts(summary) {
  if (!summary || typeof summary !== 'object') return false;
  // The headline is Learned / Mastered / Retained, so at least one of *those*
  // has to be non-zero — not `total`, which also counts concepts the learner
  // has merely been exposed to. A learner who has met three ideas and
  // explained none would otherwise be shown three zeroes as their headline:
  // the exact fabrication this rule exists to prevent, and a more damning one
  // than showing their XP.
  const counted = ['learned', 'retained', 'mastered'].map((key) => Number(summary[key]));
  return counted.some((value) => Number.isFinite(value) && value > 0);
}

/**
 * Has this learner demonstrably done something?
 *
 * Used to decide whether Home shows a learner dashboard at all. A different
 * question from `shouldLeadWithConcepts`, and it was a mistake to alias them:
 * merely *meeting* three concepts is real activity — that learner is not a
 * stranger and greeting them with the front door discards what they showed us
 * — while it is not yet anything worth putting in a headline.
 *
 * So this counts every concept with evidence; the headline rule above counts
 * only the ones that reached a rung worth naming.
 */
export function hasConceptEvidence(summary) {
  if (!summary || typeof summary !== 'object') return false;
  const total = Number(summary.total);
  return Number.isFinite(total) && total > 0;
}

// ─── Saying a record back to the learner ─────────────────────────────────────

/**
 * How each rung is named to the person who earned it.
 *
 * The wording is the product's honesty surface. "You recognised this" and
 * "you can apply this" are different claims about the same person, and the
 * gap between them is the whole reason the ladder exists — so the copy keeps
 * them apart rather than reaching for a warmer word that blurs them.
 *
 * `exposure` is deliberately the flattest of the six: being shown something
 * is proof of nothing, and the record says so rather than crediting
 * attendance.
 */
export const RUNG_CLAIMS = Object.freeze({
  exposure: Object.freeze({
    label: 'Seen',
    claim: 'You were taught this',
    caveat: 'Being shown something is not yet evidence you know it.',
  }),
  recognition: Object.freeze({
    label: 'Recognised',
    claim: 'You picked it out correctly',
    caveat: 'Choosing the right option is not the same as being able to use it.',
  }),
  explanation: Object.freeze({
    label: 'Explained',
    claim: 'You put it in your own words',
  }),
  application: Object.freeze({
    label: 'Applied',
    claim: 'You used it on a problem',
  }),
  transfer: Object.freeze({
    label: 'Transferred',
    claim: 'You used it on something new',
  }),
  retention: Object.freeze({
    label: 'Remembered',
    claim: 'You still had it after a gap',
  }),
});

/**
 * The learner-facing name and claim for a rung.
 *
 * Returns null for anything unrecognised rather than inventing a label. A new
 * server-side rung must show as nothing rather than be described with the
 * wrong words — the same rule `normalizeEvidenceKind` follows.
 */
export function rungClaim(kind) {
  const normalized = normalizeEvidenceKind(kind);
  return normalized ? RUNG_CLAIMS[normalized] ?? null : null;
}

/**
 * One line summarising where a concept stands.
 *
 * MASTERED is the only state that gets a strong word, and it is earned by
 * three separate demonstrations rather than by a high score on one.
 */
export const STATE_HEADLINES = Object.freeze({
  NOT_SEEN: 'Not started',
  EXPOSED: 'Taught, not yet shown',
  RECOGNIZED: 'Recognised so far',
  EXPLAINED: 'You can explain it',
  APPLIED: 'You can use it',
  TRANSFERRED: 'You can use it somewhere new',
  RETAINED: 'It stuck',
  MASTERED: 'Applied, transferred and retained',
});

export function stateHeadline(state) {
  return STATE_HEADLINES[state] ?? STATE_HEADLINES.NOT_SEEN;
}

/**
 * What to tell the learner to do next about one concept.
 *
 * Reads the server's `next_rung` rather than deciding here, so the advice
 * and the record cannot disagree. Returns null when the server named no next
 * step, which is what the top of the ladder looks like.
 */
export function nextStepLabel(nextRung) {
  const claim = rungClaim(nextRung);
  if (!claim) return null;
  switch (normalizeEvidenceKind(nextRung)) {
    case 'recognition': return 'Next: try a question on it';
    case 'explanation': return 'Next: explain it in your own words';
    case 'application': return 'Next: use it on a problem';
    case 'transfer': return 'Next: try it on something unfamiliar';
    case 'retention': return 'Next: come back to it in a few days';
    default: return null;
  }
}

/**
 * Turn a concept key into something readable.
 *
 * Concept keys are `slugify_skill` output — "quadratic-formula". This is
 * presentation only: the key itself stays the identity everywhere else, so
 * two surfaces cannot disagree about which concept is which.
 */
export function conceptLabel(conceptId) {
  const raw = (conceptId ?? '').toString().trim();
  if (!raw) return 'Untitled concept';
  const words = raw.replace(/[-_]+/g, ' ').replace(/\s+/g, ' ').trim();
  return words ? words.charAt(0).toUpperCase() + words.slice(1) : 'Untitled concept';
}
