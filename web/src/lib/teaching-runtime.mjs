export const TEACHING_ACTIONS = Object.freeze([
  'answer','diagnose','explain','demonstrate','guide','check_recall',
  'check_application','check_transfer','remediate','review','advance','pause',
]);

const CHECK_ACTIONS = new Set([
  'diagnose','guide','check_recall','check_application','check_transfer','review',
]);
const EXPLANATION_ACTIONS = new Set(['explain','demonstrate','remediate']);

export function emptyTeachingRuntimeState() {
  return {
    last_action: null,
    consecutive_checks: 0,
    consecutive_explanations: 0,
  };
}

export function reduceTeachingPolicy(previous, event) {
  const state = { ...emptyTeachingRuntimeState(), ...(previous || {}) };
  const action = typeof event?.action === 'string' && TEACHING_ACTIONS.includes(event.action)
    ? event.action
    : null;
  if (!action) return state;

  if (CHECK_ACTIONS.has(action)) {
    state.consecutive_checks = Math.min(8, state.consecutive_checks + 1);
    state.consecutive_explanations = 0;
  } else if (EXPLANATION_ACTIONS.has(action)) {
    state.consecutive_explanations = Math.min(8, state.consecutive_explanations + 1);
    state.consecutive_checks = 0;
  } else {
    state.consecutive_checks = 0;
    state.consecutive_explanations = 0;
  }
  state.last_action = action;
  return state;
}

export function teachingStateSummary(runtime, activeCourse) {
  const summary = {};
  if (runtime?.last_action) summary.teaching_runtime = { ...runtime };
  if (activeCourse && typeof activeCourse === 'object') summary.active_course = activeCourse;
  return Object.keys(summary).length ? summary : undefined;
}
