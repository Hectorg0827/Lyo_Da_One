'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { TeachingVisualCard } from '@/components/classroom/TeachingVisualView';
import { parseTeachingVisual } from '@/lib/teaching-activity.mjs';
import { useChatStore } from '@/stores/chat-store';
import type { ChatBlock, ChatMessage } from '@/types';

/** Reuses Classroom visuals without sending a Classroom or grading action. */
export default function TeachingVisualBlock({ block, message }: { block: ChatBlock; message: ChatMessage }) {
  const visual = parseTeachingVisual((block.content as Record<string, unknown>)?.visual);
  const updateVisual = useChatStore(s => s.updateVisual);
  const conversationId = useChatStore(s => s.activeConversationId);
  const pending = useRef<{ conversationId: string; values: Record<string, unknown> } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const busy = useRef(false);
  const mounted = useRef(true);
  const [saveError, setSaveError] = useState(false);

  const flush = useCallback(async () => {
    if (busy.current || !pending.current) return;
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    busy.current = true;
    let failed = false;
    try {
      // Serialize saves so a slower, older slider update cannot overwrite the
      // latest state. Coalesce intermediate positions while the request runs.
      while (pending.current) {
        const snapshot = pending.current;
        pending.current = null;
        const saved = await updateVisual(snapshot.conversationId, message.id, block.id, snapshot.values);
        if (!saved) {
          if (!pending.current) pending.current = snapshot;
          failed = true;
          break;
        }
      }
    } finally {
      busy.current = false;
      if (mounted.current) setSaveError(failed);
    }
  }, [updateVisual, message.id, block.id]);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      if (timer.current) clearTimeout(timer.current);
      void flush();
    };
  }, [flush]);

  if (!visual) return null;
  const spanish = /numerador|fracci[oó]n/i.test(visual.caption + visual.title);
  return (
    <div>
      <TeachingVisualCard id={block.id} visual={visual} spanish={spanish} onUpdate={values => {
        if (!conversationId) return;
        pending.current = { conversationId, values };
        if (timer.current) clearTimeout(timer.current);
        timer.current = setTimeout(() => { void flush(); }, 300);
      }} />
      {saveError && <p role="status" className="mt-2 text-xs text-amber-200">
        {spanish ? 'No se pudo guardar el cambio.' : 'Could not save this change.'}{' '}
        <button type="button" onClick={() => { void flush(); }} className="min-h-11 underline">
          {spanish ? 'Reintentar' : 'Retry'}
        </button>
      </p>}
    </div>
  );
}
