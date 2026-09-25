'use client';

import { useCallback, useRef, useState } from 'react';
import toast from 'react-hot-toast';
import { api } from '@/lib/api';
import { invalidateNearby } from '@/lib/community-cache';
import { friendlyError } from '@/lib/community-contract.mjs';
import type { LearningNode, RSVPStatus } from '@/types';

type Patch = Partial<LearningNode>;

/**
 * Save and RSVP with an instant response. The UI changes immediately, the
 * server's answer then replaces the guess (so counts and state are exactly
 * what every other device will see), and a failure puts things back and says
 * so. Nothing here is stored on the device: `onConfirmed` re-reads the
 * account from the backend.
 */
export function useCommunityActions(onConfirmed: () => void) {
  const [overrides, setOverrides] = useState<Record<string, Patch>>({});
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const busyRef = useRef(busy);
  busyRef.current = busy;

  const withOverride = useCallback(
    <T extends LearningNode | null | undefined>(node: T): T => {
      if (!node) return node;
      const patch = overrides[node.key];
      return (patch ? { ...node, ...patch } : node) as T;
    },
    [overrides],
  );

  const run = useCallback(
    async (node: LearningNode, optimistic: Patch, action: () => Promise<Patch | void>, verb: string) => {
      if (busyRef.current.has(node.key)) return;
      const previous = overrides[node.key];
      setBusy((current) => new Set(current).add(node.key));
      setOverrides((current) => ({ ...current, [node.key]: { ...current[node.key], ...optimistic } }));
      try {
        const confirmed = await action();
        setOverrides((current) => ({
          ...current,
          [node.key]: { ...current[node.key], ...optimistic, ...(confirmed || {}) },
        }));
        invalidateNearby();
        onConfirmed();
      } catch (error) {
        setOverrides((current) => {
          const next = { ...current };
          if (previous) next[node.key] = previous;
          else delete next[node.key];
          return next;
        });
        const message = friendlyError(error, verb);
        toast.error(message.body && message.title.startsWith("That didn't") ? message.body : message.title);
      } finally {
        setBusy((current) => {
          const next = new Set(current);
          next.delete(node.key);
          return next;
        });
      }
    },
    [onConfirmed, overrides],
  );

  const toggleSave = useCallback(
    (node: LearningNode) => {
      const saving = !node.is_saved;
      api.community.track('community_event_saved', { kind: node.kind, saved: saving });
      return run(
        node,
        { is_saved: saving },
        async () => {
          if (saving) {
            const saved = await api.community.saveNode(node);
            return { is_saved: true, title: saved.title };
          }
          await api.community.unsaveNode(node.kind, node.id);
          return { is_saved: false };
        },
        saving ? 'save this' : 'remove this from your saved items',
      );
    },
    [run],
  );

  const setRsvp = useCallback(
    (node: LearningNode, status: RSVPStatus | null) => {
      const previous = node.rsvp_status ?? null;
      const going = (node.going_count ?? 0) + (status === 'going' ? 1 : 0) - (previous === 'going' ? 1 : 0);
      const interested =
        (node.interested_count ?? 0) + (status === 'interested' ? 1 : 0) - (previous === 'interested' ? 1 : 0);
      api.community.track('community_event_rsvp', { status: status ?? 'none' });
      return run(
        node,
        {
          rsvp_status: status,
          is_attending: status !== null,
          going_count: Math.max(0, going),
          interested_count: Math.max(0, interested),
        },
        async () => {
          if (status === null) {
            await api.community.clearRsvp(node.id);
            return { rsvp_status: null, is_attending: false, meeting_url: null };
          }
          return api.community.setRsvp(node.id, status);
        },
        'update your RSVP',
      );
    },
    [run],
  );

  const toggleMembership = useCallback(
    (node: LearningNode) => {
      const joining = !node.is_joined;
      return run(
        node,
        { is_joined: joining, member_count: Math.max(0, (node.member_count ?? 0) + (joining ? 1 : -1)) },
        async () => {
          if (joining) await api.community.joinGroup(node.id);
          else await api.community.leaveGroup(node.id);
        },
        joining ? 'join this group' : 'leave this group',
      );
    },
    [run],
  );

  /**
   * Fresh server data arrived: it is the truth now (another device may have
   * changed it), so drop every guess except the ones still in flight.
   */
  const clearSettled = useCallback(() => {
    setOverrides((current) => {
      const inFlight = busyRef.current;
      const keys = Object.keys(current);
      if (!keys.length) return current;
      const next: Record<string, Patch> = {};
      for (const key of keys) if (inFlight.has(key)) next[key] = current[key];
      return next;
    });
  }, []);

  return { withOverride, toggleSave, setRsvp, toggleMembership, busy, clearSettled };
}
