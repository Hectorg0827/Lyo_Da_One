import type { ReadinessPayload, StudySessionRow } from '@/types';
import type { CoachReadiness } from '@/lib/coach-api';
import type { PrepMaterial, PrepProfile } from '@/lib/test-prep-api';

export type MaterialKind = 'pdf' | 'image' | 'note';
export type MaterialFilterKey = 'all' | MaterialKind;

export interface MaterialFilter {
  key: MaterialFilterKey;
  label: string;
  count: number;
}

export interface TimelineBlock {
  id: string;
  topic: string;
  sessionType: string;
  status: string;
  done: boolean;
  /** Minutes from midnight in the study timezone. */
  startOfDayMinutes: number;
  /** Minutes from the top of the rendered window. */
  startMinutes: number;
  durationMinutes: number;
  /** The row as the server sent it, for `sessionEntryHref`. */
  session: StudySessionRow;
}

export interface TimelineDay {
  /** `YYYY-MM-DD` in the study timezone. */
  key: string;
  weekday: string;
  dayOfMonth: number;
  isToday: boolean;
  totalMinutes: number;
  status: 'rest' | 'scheduled' | 'done';
  blocks: TimelineBlock[];
}

export interface Timeline {
  days: TimelineDay[];
  hours: number[];
  startHour: number;
  endHour: number;
  /** Height of the window in minutes, for `top`/`height` arithmetic. */
  totalMinutes: number;
}

/** What kind of claim a tile is making; `muted` is "we did not measure this". */
export type KpiTone = 'plain' | 'good' | 'warn' | 'urgent' | 'muted';

export interface Kpi {
  key: 'days' | 'readiness' | 'streak' | 'today';
  icon: 'calendar' | 'target' | 'flame' | 'clock';
  label: string;
  value: string;
  detail: string;
  tone: KpiTone;
}

export function sessionDate(value: string): Date;

export function weekTimeline(
  sessions: readonly StudySessionRow[] | null | undefined,
  options?: { timezone?: string | undefined; now?: Date | undefined },
): Timeline;

export function hourLabel(hour: number): string;

export function materialKind(material: unknown): MaterialKind;
export function materialFilters(materials: readonly PrepMaterial[] | null | undefined): MaterialFilter[];
export function filterMaterials(
  materials: readonly PrepMaterial[] | null | undefined,
  key: MaterialFilterKey | null | undefined,
): PrepMaterial[];

export function buildKpis(input: {
  readiness?: ReadinessPayload | null | undefined;
  coachReadiness?: CoachReadiness | null | undefined;
  profile?: PrepProfile | null | undefined;
  streak?: { current: number; best: number } | null | undefined;
  missionMinutes?: number | undefined;
  missionCount?: number | undefined;
  dueCount?: number | undefined;
  now?: Date | undefined;
}): Kpi[];

/**
 * `unmeasured` means nothing was assessed; `unknown` means the call failed.
 * Neither may be drawn as an arc at zero.
 */
export type RingStanding =
  | { kind: 'measured'; percent: number }
  | { kind: 'unmeasured'; percent: null }
  | { kind: 'unknown'; percent: null };

export function readinessRing(
  coachReadiness?: CoachReadiness | null | undefined,
  readiness?: ReadinessPayload | null | undefined,
): RingStanding;

export function missionChecklist<T extends { concept_id?: string | undefined }>(
  mission: readonly T[] | null | undefined,
  sessions: readonly StudySessionRow[] | null | undefined,
): Array<T & { done: boolean }>;

export function milestoneForWeek<T extends { week: number; focus: string }>(
  milestones: readonly T[] | null | undefined,
  /** The displayed week's Monday, as `TimelineDay.key`. */
  weekStartKey: string | null | undefined,
  sessions: readonly StudySessionRow[] | null | undefined,
  timeZone?: string | undefined,
): T | null;

export function planProgress(
  sessions: readonly StudySessionRow[] | null | undefined,
): { done: number; total: number };
