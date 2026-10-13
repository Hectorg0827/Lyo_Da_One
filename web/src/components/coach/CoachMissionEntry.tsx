'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import type { CoachGoal, CoachMissionItem } from '@/lib/coach-api';
import { missionEntryHref } from '@/lib/coach.mjs';
import { beginMissionJourney, missionJourneyPlan } from '@/lib/journey-handoff.mjs';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

type Props = {
  mission: CoachMissionItem;
  goal?: CoachGoal | null;
  origin: 'coach' | 'test_prep' | 'chat';
  profileId?: string | null;
  className: string;
  children: ReactNode;
};

/**
 * Feature-flagged entry into the server-owned learning journey.
 *
 * With the flag OFF, preserves the current direct Classroom entry.
 * With the flag ON and a valid goal, save the journey and its handoff
 * before navigation. Failures do not silently claim state persistence.
 */
export default function CoachMissionEntry({ mission, goal, origin, profileId, className, children }: Props) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState(false);
  const mounted = useRef(false);
  const busy = useRef(false);
  const keys = useRef<{ start: string; handoff: string } | null>(null);
  const { user, isAuthenticated } = useAuthStore();

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const href = missionEntryHref(mission);
  if (!href) return <div className={className}>{children}</div>;

  const enabled = process.env.NEXT_PUBLIC_LYO_JOURNEYS_ENABLED === '1';
  const plan = enabled ? missionJourneyPlan(mission, goal, origin, profileId) : null;

  if (!plan || !isAuthenticated) {
    return <Link href={href} className={className}>{children}</Link>;
  }

  const begin = async () => {
    if (busy.current) return;
    busy.current = true;
    setPending(true);
    setError(false);
    const ownerId = user?.id;
    if (!keys.current) {
      keys.current = { start: crypto.randomUUID(), handoff: crypto.randomUUID() };
    }
    try {
      const target = await beginMissionJourney(plan, api.coach.journeys, keys.current);
      // Ignore late requests from an account that just signed out/switched.
      const now = useAuthStore.getState();
      if (mounted.current && now.isAuthenticated && now.user?.id === ownerId) {
        keys.current = null;
        router.push(target);
      }
    } catch {
      if (mounted.current) setError(true);
      // Reuse the same request IDs on Retry: the server may have committed
      // the initial write despite the network failure.
    } finally {
      busy.current = false;
      if (mounted.current) setPending(false);
    }
  };

  return (
    <div>
      <button type="button" onClick={() => void begin()} disabled={pending}
        className={className} aria-busy={pending}>
        {children}
        {pending && <span className="text-xs text-white/55">Saving your place…</span>}
      </button>
      {error && (
        <p role="alert" className="mt-2 text-xs leading-5 text-amber-200">
          Could not save your learning journey.
          {' '}<button type="button" onClick={() => void begin()} className="underline underline-offset-2">Retry</button>
          {' · '}<Link href={href} className="underline underline-offset-2">
            Open without tracking the transition
          </Link>
        </p>
      )}
    </div>
  );
}
