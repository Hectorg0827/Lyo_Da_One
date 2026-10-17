/**
 * Pure journey-navigation helpers. Existing Chat, Classroom, Coach, and Test
 * Prep remain the pedagogical executors. The journey only saves navigation
 * context. No client-side LLM, assessment, or evidence mutations.
 */
import { missionEntryHref } from './coach.mjs';
import { sessionEntryHref } from './test-prep.mjs';

const CLASSROOM_PATH = /^\/classroom(?:\?|$)/;

export function withJourneyId(href, journeyId) {
  if (typeof href !== 'string' || !CLASSROOM_PATH.test(href)) return null;
  if (typeof journeyId !== 'string' || !/^[a-zA-Z0-9-]{1,80}$/.test(journeyId)) return null;
  const url = new URL(href, 'https://lyo.invalid');
  url.searchParams.set('journeyId', journeyId);
  return url.pathname + url.search;
}

export function returnFromJourney(journey) {
  if (journey?.origin_surface === 'test_prep') {
    const profileId = journey.context?.test_profile_id;
    if (typeof profileId !== 'string' || !profileId) return '/test-prep';
    const sessionId = journey.context?.study_session_id;
    const suffix = typeof sessionId === 'string' && /^[a-zA-Z0-9-]{1,36}$/.test(sessionId)
      ? '&sessionId=' + encodeURIComponent(sessionId) : '';
    return '/test-prep?profileId=' + encodeURIComponent(profileId) + suffix;
  }
  if (journey?.origin_surface === 'chat') return '/chat';
  return '/'; // Coach/Home — no untrusted redirect URL
}

/** A Coach mission can be joined to one goal, never an arbitrary exam. */
export function missionJourneyPlan(item, goal, originSurface = 'coach', profileId = null) {
  if (!item?.goal_id || !goal?.id || item.goal_id !== goal.id) return null;
  if (originSurface !== 'coach' && originSurface !== 'test_prep' && originSurface !== 'chat') return null;
  const href = missionEntryHref(item);
  if (!href || !CLASSROOM_PATH.test(href)) return null;

  const linkedExam = goal.source_ref_type === 'test_profile' ? goal.source_ref_id : null;
  if (originSurface === 'test_prep' && (!linkedExam || linkedExam !== profileId)) return null;
  if (profileId && linkedExam && profileId !== linkedExam) return null;

  const context = {};
  if (linkedExam) context.test_profile_id = linkedExam;
  if (typeof item.concept_id === 'string' && item.concept_id.length <= 160) {
    context.concept_id = item.concept_id;
  }

  return {
    href,
    start: {
      goal_id: goal.id,
      origin_surface: originSurface,
      origin_ref: originSurface === 'coach' ? 'today' : originSurface === 'chat' ? 'chat-coach' : linkedExam,
      context,
    },
    handoff: {
      expected_revision: 0,
      target_surface: 'classroom',
      target_ref: context.concept_id || null,
      context: {},
    },
  };
}

/** A scheduled study block is a real Test Prep record, not a fabricated quiz.
 * Backend rechecks the session against the selected learner-owned exam.
 */
export function studySessionJourneyPlan(session, goal, profileId) {
  const linkedExam = goal?.source_ref_type === 'test_profile' ? goal.source_ref_id : null;
  if (!linkedExam || linkedExam !== profileId || !goal?.id ||
      !session || typeof session.id !== 'string' ||
      !/^[a-zA-Z0-9-]{1,36}$/.test(session.id)) return null;
  const href = sessionEntryHref(session);
  if (!href || !CLASSROOM_PATH.test(href)) return null;
  return {
    href,
    start: {
      goal_id: goal.id,
      origin_surface: 'test_prep',
      origin_ref: linkedExam,
      context: {
        test_profile_id: linkedExam,
        study_session_id: session.id,
      },
    },
    handoff: {
      expected_revision: 0,
      target_surface: 'classroom',
      target_ref: session.id,
      context: {},
    },
  };
}

/** A retry reuses the same caller-supplied IDs; success can clear them. */
export async function createMissionJourney({ start, handoff }, journeyApi, ids) {
  if (!ids?.start || !ids?.handoff) throw Error('Missing journey idempotency keys');
  const journey = await journeyApi.start({ ...start, request_id: ids.start });
  const event = await journeyApi.handoff(journey.id, { ...handoff, request_id: ids.handoff });
  // The actual Classroom destination comes from the caller's validated plan.
  return { journey, event };
}

export async function beginMissionJourney(plan, journeyApi, ids) {
  if (!plan) throw Error('Missing journey plan');
  const { journey } = await createMissionJourney(plan, journeyApi, ids);
  const href = withJourneyId(plan.href, journey.id);
  if (!href) throw Error('Invalid journey destination');
  return href;
}
