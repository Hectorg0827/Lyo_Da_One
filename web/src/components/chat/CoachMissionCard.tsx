'use client';

import Link from 'next/link';

import type { CoachToday } from '@/lib/coach-api';
import {
  actionLabel,
  missionEntryHref,
  readinessExplanation,
  readinessLabel,
} from '@/lib/coach.mjs';

interface CoachMissionCardProps {
  view: CoachToday;
  timeBudgetMinutes?: number | null;
}

/**
 * Structured face of the canonical Lyo Coach mission inside Chat.
 *
 * The backend owns the goal, evidence and pedagogical action. This component
 * only renders that decision and hands each action to the existing Classroom
 * entry contract. It never computes mastery or invents a second quiz flow.
 */
export default function CoachMissionCard({
  view,
  timeBudgetMinutes,
}: CoachMissionCardProps) {
  const primaryGoal =
    view.active_goals.find((goal) => goal.id === view.primary_goal_id)
    ?? view.active_goals[0]
    ?? null;
  const readiness = primaryGoal ? view.readiness[primaryGoal.id] : undefined;

  if (!primaryGoal) return null;

  return (
    <section
      aria-label="Lyo Coach mission"
      className="w-full overflow-hidden rounded-2xl border border-violet-400/20 bg-violet-400/[0.07]"
    >
      <div className="border-b border-white/8 px-4 py-3">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-violet-200/70">
              Lyo Coach
            </p>
            <h3 className="mt-1 truncate text-sm font-semibold text-white">
              {primaryGoal.title}
            </h3>
            {readiness && (
              <p className="mt-1 text-xs text-white/65">
                {readinessLabel(readiness)}
                {' · '}
                {readiness.assessed_skills}/{readiness.total_skills} skills assessed
              </p>
            )}
          </div>
          <div className="shrink-0 rounded-full border border-white/10 px-2.5 py-1 text-[11px] text-white/60">
            {view.total_minutes} min
          </div>
        </div>

        {readiness && (
          <p className="mt-2 text-xs leading-5 text-white/55">
            {readinessExplanation(readiness)}
          </p>
        )}
        {timeBudgetMinutes != null && (
          <p className="mt-1.5 text-[11px] text-violet-100/60">
            Built for your {timeBudgetMinutes}-minute window.
          </p>
        )}
      </div>

      {view.mission.length > 0 ? (
        <div className="space-y-1.5 p-2">
          {view.mission.map((item, index) => {
            const href = missionEntryHref(item);
            const body = (
              <>
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-white/8 text-[11px] font-semibold text-white/60">
                  {index + 1}
                </span>
                <span className="min-w-0 flex-1 text-left">
                  <span className="block truncate text-xs font-medium text-white/90">
                    {item.title}
                  </span>
                  <span className="block text-[11px] text-white/45">
                    {actionLabel(item.action)} · {item.estimated_minutes} min
                  </span>
                </span>
                <span aria-hidden className="text-sm text-violet-200/70">→</span>
              </>
            );

            return href ? (
              <Link
                key={`${item.goal_id}:${item.skill_id}`}
                href={href}
                className="flex min-h-11 items-center gap-2 rounded-xl px-2.5 py-2 transition-colors hover:bg-white/7 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-300/70"
              >
                {body}
              </Link>
            ) : (
              <div
                key={`${item.goal_id}:${item.skill_id}`}
                className="flex min-h-11 items-center gap-2 rounded-xl px-2.5 py-2 opacity-70"
              >
                {body}
              </div>
            );
          })}
        </div>
      ) : (
        <p className="px-4 py-3 text-xs text-white/55">
          Your active goals are caught up. A light review is enough for now.
        </p>
      )}
    </section>
  );
}
