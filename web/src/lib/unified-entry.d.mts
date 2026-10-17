export interface UnifiedLearningOptions {
  goal?: string;
  level?: string;
  minutes?: number;
  language?: string;
  objective?: string;
}
export type UnifiedLearningSurface = 'chat' | 'classroom' | 'test_prep_intake' | 'coach_chat';
export interface UnifiedLearningRoute {
  surface: UnifiedLearningSurface;
  href: string;
  reason: string;
}
export function routeLearningRequest(input: string | null | undefined, options?: UnifiedLearningOptions): UnifiedLearningRoute | null;
export function directLearningHref(surface: 'chat' | 'classroom' | 'test_prep' | string, input?: string): string | null;
