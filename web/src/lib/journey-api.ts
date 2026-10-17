/** Additive contract for the LyoBackendJune Coach journey API (PR #134).
 * Navigation references are not authority to grade or read underlying exams.
 */
export type JourneySurface = 'chat' | 'classroom' | 'test_prep' | 'coach';

export interface JourneyContext {
  chat_session_id?: string;
  test_profile_id?: string;
  course_id?: string;
  lesson_id?: string;
  concept_id?: string;
  question_id?: string;
  study_session_id?: string;
}

export interface LearningJourney {
  id: string;
  goal_id: string;
  origin_surface: JourneySurface;
  origin_ref?: string | null;
  active_surface: JourneySurface;
  active_ref?: string | null;
  status: 'active' | 'paused' | 'completed';
  revision: number;
  context: JourneyContext;
  updated_at: string;
}

export interface JourneyHandoff {
  id: string;
  revision: number;
  from_surface: JourneySurface;
  from_ref?: string | null;
  to_surface: JourneySurface;
  to_ref?: string | null;
  context: JourneyContext;
  created_at: string;
}

export interface JourneyStartPayload {
  request_id: string;
  goal_id: string;
  origin_surface: JourneySurface;
  origin_ref?: string | null;
  context: JourneyContext;
}

export interface JourneyHandoffPayload {
  request_id: string;
  expected_revision: number;
  target_surface: JourneySurface;
  target_ref?: string | null;
  context: JourneyContext;
}
