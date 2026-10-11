export interface VisualSaveUpdate {
  conversationId: string;
  messageId: string;
  blockId: string;
  values: Record<string, unknown>;
}
export interface VisualSaveSnapshot {
  values: Record<string, unknown>;
  failed: boolean;
}
export function createVisualSaveQueue(
  save: (update: VisualSaveUpdate) => Promise<boolean>, delayMs?: number,
): {
  keyFor(update: Omit<VisualSaveUpdate, 'values'>): string;
  enqueue(update: VisualSaveUpdate): void;
  flush(key: string): Promise<void>;
  getSnapshot(key: string): VisualSaveSnapshot | null;
  subscribe(key: string, listener: () => void): () => void;
};
