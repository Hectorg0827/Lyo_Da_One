'use client';

import { api } from '@/lib/api';

export type VoiceQualityMetric = number | boolean | string;

export interface VoiceQualityContext {
  sessionId: string;
  turnId?: string;
  conversationId?: string;
  locale?: string;
  scenario?: string;
}

export function voiceQualityNow(): number {
  return typeof performance !== 'undefined' ? performance.now() : Date.now();
}

export function createVoiceQualitySessionId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return `voice-${crypto.randomUUID()}`;
  }
  return `voice-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function detectLanguageFamily(text: string): 'en' | 'es' | 'mixed' | 'unknown' {
  const normalized = text.toLocaleLowerCase();
  const english = (normalized.match(/\b(?:the|and|what|how|why|is|are|this|that|because|please|can|you|tell|explain)\b/g) ?? []).length;
  const spanish = (normalized.match(/\b(?:el|la|los|las|y|que|qué|como|cómo|por|porque|esto|esta|puedes|dime|explica|gracias)\b/g) ?? []).length;
  if (english >= 2 && spanish >= 2) return 'mixed';
  if (spanish >= 2) return 'es';
  if (english >= 2) return 'en';
  return 'unknown';
}

/**
 * Fire-and-forget, privacy-bounded voice QA telemetry.
 *
 * Callers may send timings, booleans, language-family labels and transport
 * outcomes. Never send transcript text, audio, filenames, questions, answers,
 * or other learner-authored content.
 */
export function reportVoiceQuality(
  context: VoiceQualityContext,
  event: string,
  metrics: Record<string, VoiceQualityMetric> = {},
): void {
  if (!context.sessionId) return;
  void api.chat.reportVoiceQuality({
    session_id: context.sessionId.slice(0, 128),
    turn_id: context.turnId?.slice(0, 128),
    conversation_id: context.conversationId?.slice(0, 128),
    platform: 'web',
    event,
    locale: context.locale?.slice(0, 32),
    scenario: context.scenario?.slice(0, 64),
    metrics,
  }).catch(() => {
    // QA telemetry must never interfere with the voice conversation itself.
  });
}

let activeContext: VoiceQualityContext | null = null;

export function setActiveVoiceQualityContext(context: VoiceQualityContext | null): void {
  activeContext = context;
}

export function getActiveVoiceQualityContext(): VoiceQualityContext | null {
  return activeContext;
}

export function reportActiveVoiceQuality(
  event: string,
  metrics: Record<string, VoiceQualityMetric> = {},
  patch: Partial<VoiceQualityContext> = {},
): void {
  if (!activeContext) return;
  reportVoiceQuality({ ...activeContext, ...patch }, event, metrics);
}
