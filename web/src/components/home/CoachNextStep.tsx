'use client';

import { useEffect, useState } from 'react';
import CoachMissionEntry from '@/components/coach/CoachMissionEntry';
import { ArrowRight, BrainCircuit, Clock3 } from 'lucide-react';
import { api } from '@/lib/api';
import type { CoachToday } from '@/lib/coach-api';
import { missionEntryHref } from '@/lib/coach.mjs';

/**
 * Read-only entry to the existing evidence-based Learning OS.
 * Never fabricates readiness, starts graded tasks, or guesses a mission.
 * The server is authoritative; older/unavailable Coach responses leave the
 * ordinary Home entry intact. No additional LLM/Coach pipeline is introduced.
 */
export default function CoachNextStep({
  enabled,
  learnerKey,
}: {
  enabled: boolean;
  learnerKey?: string;
}) {
  const [today, setToday] = useState<CoachToday | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setToday(null);
    if (!enabled) return () => { cancelled = true; };

    setLoading(true);
    api.coach.today().then((view) => {
      if (!cancelled) setToday(view);
    }).catch(() => {
      // Never invent a recommendation if evidence/auth/backend is unavailable.
      if (!cancelled) setToday(null);
    }).finally(() => {
      if (!cancelled) setLoading(false);
    });
    return () => { cancelled = true; };
  }, [enabled, learnerKey]);

  if (!enabled || loading || !today) return null;
  const item = today.mission.find((entry) => Boolean(missionEntryHref(entry)));
  if (!item) return null;
  const href = missionEntryHref(item);
  if (!href) return null;

  return (
    <section aria-label="Lyo Coach next learning step"
      className="rounded-3xl border border-white/15 bg-white/[0.05] px-4 py-4 sm:px-6">
      <div className="flex flex-wrap items-center gap-2 text-xs font-semibold text-white/70">
        <BrainCircuit size={17} aria-hidden="true" className="text-accent-teal" />
        <span>Lyo Coach</span>
        <span className="rounded-full border border-white/15 px-2 py-0.5 text-white/60">
          Evidence-based next step
        </span>
      </div>
      <div className="mt-2 flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0 flex-1">
          <h2 className="font-rounded text-lg font-bold text-white">
            Continue with {item.title}
          </h2>
          <p className="mt-1 text-xs text-white/65">{item.goal_title}</p>
          <p className="mt-1 text-sm text-white/75">{item.reason}</p>
          <span className="mt-2 inline-flex items-center gap-1 text-xs text-white/65">
            <Clock3 size={13} aria-hidden="true" /> {item.estimated_minutes} min suggested
          </span>
        </div>
        <CoachMissionEntry mission={item}
          goal={today.active_goals.find((goal) => goal.id === item.goal_id)}
          origin="coach"
          className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-4 py-2 text-sm font-bold text-[#1b1035] hover:bg-white/90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white">
          Start this step <ArrowRight size={16} aria-hidden="true" />
        </CoachMissionEntry>
      </div>
    </section>
  );
}
