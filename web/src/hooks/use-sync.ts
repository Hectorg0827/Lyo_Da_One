'use client';

import { useEffect, useRef } from 'react';
import { syncClient, type SyncEvent, type SyncEventType } from '@/lib/sync';

/**
 * Subscribe a component to cross-device sync events.
 *
 * @param handler called for every event (or only `types`, if given)
 * @param types   optional filter of event types to receive
 *
 * Example — refresh messages when another device sends one:
 *   useSyncEvents(() => refetchMessages(), ['message_sent', 'message_received']);
 */
export function useSyncEvents(
  handler: (event: SyncEvent) => void,
  types?: SyncEventType[]
) {
  const handlerRef = useRef(handler);
  handlerRef.current = handler;

  const typesKey = types ? types.join(',') : '';

  useEffect(() => {
    const filter = typesKey ? typesKey.split(',') : null;
    return syncClient.subscribe((event) => {
      if (!filter || filter.includes(event.event_type)) {
        handlerRef.current(event);
      }
    });
  }, [typesKey]);
}
