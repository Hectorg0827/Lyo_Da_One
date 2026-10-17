import type { CoachGoal, CoachMissionItem } from './coach-api';
import type { StudySessionRow } from '@/types';
import type { LearningJourney, JourneyHandoff, JourneyStartPayload, JourneyHandoffPayload } from './journey-api';

export interface MissionJourneyPlan {
  href: string;
  start: Omit<JourneyStartPayload, 'request_id'>;
  handoff: Omit<JourneyHandoffPayload, 'request_id'>;
}

export function studySessionJourneyPlan(session: StudySessionRow, goal: CoachGoal | null | undefined, profileId: string | null | undefined): MissionJourneyPlan | null;
export function withJourneyId(href: string, journeyId: string): string | null;
export function returnFromJourney(journey: LearningJourney | null | undefined): string;
export function missionJourneyPlan(item: CoachMissionItem, goal: CoachGoal | null | undefined,
  originSurface?: 'coach' | 'test_prep' | 'chat', profileId?: string | null): MissionJourneyPlan | null;
export function beginMissionJourney(plan: MissionJourneyPlan, journeyApi: {
  start: (body: JourneyStartPayload) => Promise<LearningJourney>;
  handoff: (id: string, body: JourneyHandoffPayload) => Promise<JourneyHandoff>;
}, ids: { start: string; handoff: string }): Promise<string>;
