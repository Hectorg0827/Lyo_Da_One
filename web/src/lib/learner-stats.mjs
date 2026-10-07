/**
 * The four numbers a learner is shown about themselves, built once.
 *
 * Focus renders them as a one-line strip; Profile renders them as a grid with
 * the sub-line that says what each word actually means. Those were the same
 * four numbers derived twice from the same two payloads, which is how two
 * surfaces end up disagreeing about how many concepts somebody has mastered.
 * The derivation lives here; the components only choose a shape.
 *
 * `.mjs` so the Node test runner and the parity scripts can import it, matching
 * learner-model.mjs and entry-contract.mjs.
 */

import { shouldLeadWithConcepts } from './learner-model.mjs';

/**
 * A finite number, or null. Null means "no reading", never zero.
 *
 * The coercion is deliberately narrow, because `Number()` is not: `Number(null)`
 * is 0, and so are `Number('')`, `Number(false)` and `Number([])`. Writing this
 * as `Number.isFinite(Number(value))` therefore turned every explicit null the
 * server sent into a real reading of zero — and a FastAPI route with
 * `Optional[int] = None` serialises exactly that. A learner on a seven-day
 * streak was shown "0d" the moment the overview reported `"current": null`,
 * and the fallback to their profile's own streak never ran because 0 looked
 * like an answer.
 *
 * So: a number is a reading, a non-blank numeric string is a reading, and
 * everything else — null, undefined, '', booleans, arrays, objects — is the
 * absence of one. That is the same rule `normalizeMastery` follows in
 * learner-model.mjs, and for the same reason: "never assessed" and "assessed
 * at zero" are different claims about a person.
 */
function num(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

/** First finite, non-negative reading in the list; 0 if there is none. */
function firstCount(...values) {
  for (const value of values) {
    const n = num(value);
    if (n !== null && n >= 0) return n;
  }
  return 0;
}

/**
 * The learner's streak, from whichever of the two shapes carries it.
 *
 * `gamification.streaks` is the authority; the user profile is the fallback
 * for a backend that has not sent one yet.
 */
export function streakFrom(gamification, user) {
  const streaks = gamification?.streaks ?? {};
  const current = firstCount(streaks.current, user?.streak);
  const best = firstCount(streaks.longest, streaks.best, current);
  return { current, best: Math.max(best, current) };
}

/**
 * Build the four stats, and say which kind they are.
 *
 * `kind` is 'concepts' when the learner has demonstrated something worth
 * naming — see `shouldLeadWithConcepts` for why that is a higher bar than
 * "has any evidence at all" — and 'activity' otherwise. Concepts lead because
 * XP, hours and streak measure attendance: a learner with a thirty-day streak
 * still cannot tell from that whether they understand anything.
 *
 * Every figure comes from a payload. Nothing here invents a number to fill a
 * slot, and a missing reading counts as 0 only where 0 is the truth (nobody
 * has a negative streak), never where it would be a claim about the learner.
 */
export function buildLearnerStats({ conceptSummary, gamification, user } = {}) {
  const { current, best } = streakFrom(gamification, user);
  const bestTrend = best > current ? `Best: ${best}d` : '';

  const streakStat = (icon) => ({
    key: 'streak',
    label: 'Streak',
    short: 'Streak',
    value: `${current}d`,
    sub: 'current',
    icon,
    color: '#ec4899',
    trend: bestTrend,
  });

  if (shouldLeadWithConcepts(conceptSummary)) {
    const exploring = firstCount(conceptSummary.exploring);
    return {
      kind: 'concepts',
      stats: [
        {
          key: 'learned',
          label: 'Learned',
          short: 'Learned',
          value: String(firstCount(conceptSummary.learned)),
          sub: 'concepts explained',
          icon: 'book',
          color: '#6366f1',
          trend: exploring > 0 ? `${exploring} exploring` : '',
        },
        {
          key: 'mastered',
          label: 'Mastered',
          short: 'Mastered',
          value: String(firstCount(conceptSummary.mastered)),
          sub: 'applied, transferred, retained',
          icon: 'trophy',
          color: '#22c55e',
          trend: '',
        },
        {
          key: 'retained',
          label: 'Retained',
          short: 'Retained',
          value: String(firstCount(conceptSummary.retained)),
          sub: 'recalled after a break',
          icon: 'zap',
          color: '#f59e0b',
          trend: '',
        },
        streakStat('clock'),
      ],
    };
  }

  const xpSummary = gamification?.xp_summary ?? {};
  const userLevel = gamification?.user_level ?? {};
  const achievements = gamification?.achievements ?? {};

  const xp = firstCount(xpSummary.total, user?.xp);
  const level = firstCount(userLevel.level, user?.level, 1) || 1;
  // The server's own hours when it sends them. This used to read
  // `(total_hours || xp) ? round(xp / 100) : 0`, where `||` binds tighter than
  // `?:` — so `total_hours` only ever decided *whether* to show a figure, and
  // the figure shown was always the XP-derived one. A backend reporting 40
  // hours against 0 XP displayed "0 Hours Learned".
  const hours = num(userLevel.total_hours) ?? Math.round(xp / 100);

  return {
    kind: 'activity',
    stats: [
      {
        key: 'hours',
        label: 'Hours Learned',
        short: 'Hours',
        value: String(Math.max(0, hours)),
        sub: 'total',
        icon: 'clock',
        color: '#6366f1',
        trend: '',
      },
      {
        key: 'courses',
        label: 'Courses Done',
        short: 'Courses',
        value: String(firstCount(achievements.completed, user?.coursesCompleted)),
        sub: 'total completed',
        icon: 'book',
        color: '#22c55e',
        trend: '',
      },
      {
        key: 'xp',
        label: 'XP Earned',
        short: 'XP',
        value: String(xp),
        sub: 'total',
        icon: 'zap',
        color: '#f59e0b',
        trend: `Level ${level}`,
      },
      streakStat('trophy'),
    ],
  };
}
