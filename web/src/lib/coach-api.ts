export type CoachReadinessLevel = 'not_ready' | 'getting_there' | 'ready';

export interface CoachReadiness {
  readiness_index: number;
  readiness_level: CoachReadinessLevel;
  calibrated: boolean;
  assessed_skills: number;
  total_skills: number;
  critical_gaps: number;
}

export interface CoachGoal {
  id: string;
  goal_type: string;
  title: string;
  subject?: string | null;
  status: string;
  deadline?: string | null;
  desired_outcome: Record<string, unknown>;
  constraints: Record<string, unknown>;
}

export interface CoachMissionItem {
  goal_id: string;
  goal_title: string;
  skill_id: string;
  concept_id: string;
  title: string;
  action: string;
  target_evidence_type?: string | null;
  recommended_surface: 'chat' | 'classroom' | 'quiz' | 'review';
  estimated_minutes: number;
  priority_score: number;
  reason: string;
}

export interface CoachToday {
  primary_goal_id?: string | null;
  active_goals: CoachGoal[];
  readiness: Record<string, CoachReadiness>;
  mission: CoachMissionItem[];
  total_minutes: number;
  coach_note: string;
  generated_at: string;
}
