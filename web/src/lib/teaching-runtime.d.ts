export type TeachingAction =
  | 'answer' | 'diagnose' | 'explain' | 'demonstrate' | 'guide'
  | 'check_recall' | 'check_application' | 'check_transfer'
  | 'remediate' | 'review' | 'advance' | 'pause';

export interface TeachingRuntimeState {
  last_action: TeachingAction | null;
  consecutive_checks: number;
  consecutive_explanations: number;
}

export const TEACHING_ACTIONS: readonly TeachingAction[];
export function emptyTeachingRuntimeState(): TeachingRuntimeState;
export function reduceTeachingPolicy(
  previous: TeachingRuntimeState | undefined,
  event: { action?: unknown } | undefined,
): TeachingRuntimeState;
export function teachingStateSummary(
  runtime: TeachingRuntimeState | undefined,
  activeCourse?: Record<string, unknown>,
): { teaching_runtime?: TeachingRuntimeState; active_course?: Record<string, unknown> } | undefined;
