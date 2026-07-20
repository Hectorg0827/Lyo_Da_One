export type ClassroomMode = 'solo' | 'classroom' | 'challenge' | 'review';
export type HintLevel = 'nudge' | 'principle' | 'worked_step' | 'full_example' | 'prerequisite';

export interface ClassroomContractConnection {
  topic: string;
  sessionId?: string;
  objective?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  mode?: ClassroomMode;
  durationMinutes?: number;
  reducedMotion?: boolean;
}

export const CLASSROOM_MODES: readonly ClassroomMode[];
export const HINT_LEVELS: readonly HintLevel[];
export function normalizeClassroomMode(value?: string): ClassroomMode;
export function buildClassroomWsUrl(
  apiUrl: string,
  connection: ClassroomContractConnection,
  token: string | null,
): string;
export function isTransferReady(response: string, minWords?: number): boolean;
