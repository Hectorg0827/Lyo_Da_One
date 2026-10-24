'use client';

import { useCallback, useEffect, useState } from 'react';
import { Loader2, UserX } from 'lucide-react';
import toast from 'react-hot-toast';
import { api } from '@/lib/api';

type Blocked = { user_id: number; user_name: string };

/**
 * The accounts this learner has blocked, each with Unblock.
 *
 * A block hides both people from each other in Discover and Community, and
 * it is made from Report on one of their videos. Unblocking brings their
 * videos and comments back.
 */
export default function BlockedAccounts() {
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading');
  const [blocked, setBlocked] = useState<Blocked[]>([]);
  const [busyIds, setBusyIds] = useState<Set<number>>(() => new Set());

  const load = useCallback(() => {
    setState('loading');
    api.blocks
      .list()
      .then((list) => {
        setBlocked(list || []);
        setState('ready');
      })
      .catch(() => setState('error'));
  }, []);

  useEffect(load, [load]);

  const unblock = async (account: Blocked) => {
    if (busyIds.has(account.user_id)) return;
    setBusyIds((current) => new Set(current).add(account.user_id));
    try {
      await api.blocks.unblock(String(account.user_id));
      setBlocked((current) => current.filter((item) => item.user_id !== account.user_id));
      toast(`Unblocked ${account.user_name}.`);
    } catch {
      toast.error(`Couldn't unblock ${account.user_name}. Please try again.`);
    } finally {
      setBusyIds((current) => {
        const next = new Set(current);
        next.delete(account.user_id);
        return next;
      });
    }
  };

  if (state === 'loading') {
    return (
      <p className="flex items-center gap-2 px-5 py-4 text-sm text-secondary">
        <Loader2 size={14} className="animate-spin" aria-hidden="true" /> Loading…
      </p>
    );
  }
  if (state === 'error') {
    return (
      <div className="flex items-center justify-between gap-3 px-5 py-4 text-sm">
        <span className="text-secondary">Couldn&apos;t load your blocked accounts.</span>
        <button type="button" onClick={load} className="font-semibold text-primary hover:underline">
          Try again
        </button>
      </div>
    );
  }
  if (blocked.length === 0) {
    return (
      <p className="px-5 py-4 text-sm text-secondary">
        You haven&apos;t blocked anyone. To block someone, tap Report on one of their Discover videos.
      </p>
    );
  }
  return (
    <ul>
      {blocked.map((account) => (
        <li
          key={account.user_id}
          className="flex items-center gap-3 border-b border-white/[0.04] px-5 py-3 text-sm text-primary last:border-b-0"
        >
          <UserX size={16} className="shrink-0 text-secondary" aria-hidden="true" />
          <span className="min-w-0 flex-1 truncate">{account.user_name}</span>
          <button
            type="button"
            onClick={() => void unblock(account)}
            disabled={busyIds.has(account.user_id)}
            className="rounded-lg border border-white/10 px-3 py-1.5 text-xs font-semibold text-primary transition hover:bg-white/[0.06] disabled:opacity-40"
          >
            Unblock
          </button>
        </li>
      ))}
    </ul>
  );
}
