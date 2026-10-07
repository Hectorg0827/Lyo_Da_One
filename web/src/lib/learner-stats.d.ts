/** Type surface for learner-stats.mjs — see that file for the reasoning. */

export type LearnerStatIcon = 'book' | 'trophy' | 'zap' | 'clock';

export interface LearnerStat {
  key: string;
  /** Full label, for the grid. */
  label: string;
  /** Short label (<= 8 chars), for the one-line strip. */
  short: string;
  value: string;
  /** What the label actually means — "applied, transferred, retained". */
  sub: string;
  icon: LearnerStatIcon;
  color: string;
  /** Secondary reading ("Best: 11d", "Level 3"); empty when there is none. */
  trend: string;
}

export interface LearnerStatsResult {
  /** 'concepts' once something has reached a rung worth naming. */
  kind: 'concepts' | 'activity';
  stats: LearnerStat[];
}

export function streakFrom(
  gamification: unknown,
  user: unknown,
): { current: number; best: number };

export function buildLearnerStats(payload?: {
  conceptSummary?: unknown;
  gamification?: unknown;
  user?: unknown;
}): LearnerStatsResult;
