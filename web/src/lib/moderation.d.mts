export type ModerationView = 'reported' | 'all' | 'removed';
export type ModerationAction = 'keep' | 'remove' | 'restore';
export const MODERATION_VIEWS: { id: ModerationView; label: string; empty: string }[];
export function reasonLabel(value: string): string;
export function actionsFor(clip: { moderationStatus?: string; reports?: { pending?: number } } | null | undefined): ModerationAction[];
export function statusLabel(status: string): string;
export const DECISION_MESSAGES: Record<ModerationAction, string>;
export function belongsIn(view: ModerationView, clip: { moderationStatus?: string; reports?: { pending?: number } } | null | undefined): boolean;
