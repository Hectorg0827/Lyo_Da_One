import type { StudyPlanSummary, StudySessionRow } from '@/types';

export interface PrepMaterial {
  name: string;
  uri: string;
  modality: 'IMAGE' | 'DOCUMENT';
  mime_type: string;
}
export interface PrepProfile {
  id: string;
  subject: string;
  test_date: string;
  topics: Array<{ name: string; weight?: number; confidence?: number }>;
  daily_minutes_available: number;
  study_days_per_week: number;
  materials: PrepMaterial[];
  intake_complete: boolean;
  intake_transcript: Array<{ role: string; content: string }>;
}
export interface PrepSnapshot {
  profile: PrepProfile | null;
  plan: (StudyPlanSummary & { weekly_milestones?: Array<{ week: number; focus: string }> }) | null;
  timezone: string;
  revision: number;
  sessions: StudySessionRow[];
}
export type PrepUpdate = Partial<Pick<PrepProfile,
  'subject' | 'test_date' | 'topics' | 'daily_minutes_available' | 'study_days_per_week' | 'materials'>> & {
    timezone?: string;
    expected_revision: number;
  };

export function deviceTimezone() { return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'; }
export function sessionDate(value: string) {
  return new Date(/(?:Z|[+-]\d{2}:\d{2})$/.test(value) ? value : `${value}Z`);
}
