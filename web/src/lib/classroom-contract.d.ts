export type ClassroomMode = 'solo' | 'classroom' | 'challenge' | 'review';
export type HintLevel = 'nudge' | 'principle' | 'worked_step' | 'full_example' | 'prerequisite';

export interface ClassroomContractConnection {
  topic: string;
  sessionId?: string;
  courseId?: string;
  recordScope?: 'unit' | 'topic';
  lessonId?: string;
  reviewConceptId?: string;
  objective?: string;
  difficulty?: 'beginner' | 'intermediate' | 'advanced';
  mode?: ClassroomMode;
  durationMinutes?: number;
  reducedMotion?: boolean;
  language?: string;
}

export const CLASSROOM_MODES: readonly ClassroomMode[];
export const HINT_LEVELS: readonly HintLevel[];
export function normalizeClassroomMode(value?: string): ClassroomMode;
export function classroomSceneStart(message: unknown): {
  scene: unknown;
  inlineComponents: Array<{ type?: string; [key: string]: unknown }>;
} | null;
export function buildClassroomWsUrl(
  apiUrl: string,
  connection: ClassroomContractConnection,
  token: string | null,
): string;
export function isTransferReady(response: string, minWords?: number): boolean;

export interface ClassroomSavedSession {
  id: string;
  startedAt: number;
  generation: number;
}

export interface ClassroomSessionStart {
  sessionId: string;
  generation: number;
  resumed: boolean;
}

export interface ClassroomOpening {
  title: string;
  objective: string;
  facts: string[];
  note: string;
  resumed: boolean;
}

export function classroomCourseKey(connection: {
  courseId?: string;
  topic?: string;
} | null | undefined): string;
export function classroomSessionStorageKey(courseKey: string): string;
export const CLASSROOM_RESUME_WINDOW_MS: number;
export function canResumeClassroom(
  saved: ClassroomSavedSession | null | undefined,
  now?: number,
): boolean;
export function classroomSessionStart(
  courseKey: string,
  saved: ClassroomSavedSession | null | undefined,
  options?: { resume?: boolean; now?: number },
): ClassroomSessionStart;
export const CLASSROOM_STALL_NOTICE_MS: number;
export const CLASSROOM_STALL_RECOVERY_MS: number;
export const CLASSROOM_STALL_NOTICE: string;
export const CLASSROOM_STALL_RECOVERY: string;
export const CLASSROOM_OPENING_NOTE: string;
export function classroomOpening(input?: {
  topic?: string;
  objective?: string;
  durationMinutes?: number;
  difficulty?: string;
  mode?: string;
  resumed?: boolean;
}): ClassroomOpening;
export function defaultClassroomObjective(topic: string): string;
