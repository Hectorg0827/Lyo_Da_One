'use client';

import { useCallback, useEffect, useSyncExternalStore } from 'react';
import { TeachingVisualCard } from '@/components/classroom/TeachingVisualView';
import { parseTeachingVisual } from '@/lib/teaching-activity.mjs';
import { createVisualSaveQueue } from '@/lib/visual-save-queue.mjs';
import { useChatStore } from '@/stores/chat-store';
import type { ChatBlock, ChatMessage } from '@/types';

const saves = createVisualSaveQueue(update => useChatStore.getState().updateVisual(
  update.conversationId, update.messageId, update.blockId, update.values,
));

/** Reuses Classroom visuals without sending a Classroom or grading action. */
export default function TeachingVisualBlock({ block, message }: { block: ChatBlock; message: ChatMessage }) {
  // Resolve the message's owner, including during a conversation transition.
  const conversationId = useChatStore(s => s.conversations.find(conversation =>
    conversation.messages.some(existing => existing.id === message.id))?.id ?? s.activeConversationId);
  const key = saves.keyFor({ conversationId: conversationId ?? '', messageId: message.id, blockId: block.id });
  const subscribe = useCallback((listener: () => void) => saves.subscribe(key, listener), [key]);
  const snapshot = useSyncExternalStore(subscribe, () => saves.getSnapshot(key), () => null);
  const rawVisual = (block.content as Record<string, unknown>)?.visual;
  const visual = parseTeachingVisual(snapshot && rawVisual && typeof rawVisual === 'object'
    ? { ...rawVisual, ...snapshot.values } : rawVisual);

  // Flush when leaving; the shared queue retains retries and prevents a second
  // mounted view from sending a newer request ahead of the previous save.
  useEffect(() => () => { void saves.flush(key); }, [key]);

  if (!visual) return null;
  const spanish = /numerador|fracci[oó]n/i.test(visual.caption + visual.title);
  return (
    <div>
      <TeachingVisualCard id={block.id} visual={visual} spanish={spanish} onUpdate={values => {
        if (!conversationId) return;
        saves.enqueue({ conversationId, messageId: message.id, blockId: block.id, values });
      }} />
      {snapshot?.failed && <p role="status" className="mt-2 text-xs text-amber-200">
        {spanish ? 'No se pudo guardar el cambio.' : 'Could not save this change.'}{' '}
        <button type="button" onClick={() => { void saves.flush(key); }} className="min-h-11 underline">
          {spanish ? 'Reintentar' : 'Retry'}
        </button>
      </p>}
    </div>
  );
}
