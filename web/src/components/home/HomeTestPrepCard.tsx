'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Calendar, ChevronRight, Play } from 'lucide-react';
import { api } from '@/lib/api';
import { daysLabel, openSessions, readinessHeadline } from '@/lib/test-prep.mjs';
import type { ReadinessPayload, StudySessionRow } from '@/types';

/**
 * "I have a test on Friday. How ready am I, and what should I do first?"
 *
 * Test Prep was already a real page; Home linked to it with a CTA that said
 * nothing about the learner's own plan, so the answer was always one click
 * away and never visible. This answers it in place when there is a plan, and
 * collapses to a single line when there is not.
 *
 * Every figure comes from `test-prep.mjs` rather than being formatted again
 * here, so the distinction that module exists for still holds: a plan with
 * nothing assessed carries a readiness of 0, and "0% ready" is the same
 * number and a crueller claim than "nothing measured yet". Nothing measured
 * draws no arc.
 */

type Loaded = {
  subject: string | null;
  days: string | null;
  headline: { kind: string; percent: number | null };
  assessed: number | null;
  total: number | null;
  next: { topic: string; minutes: number | null } | null;
  stale: boolean;
};

export default function HomeTestPrepCard({
  enabled = true,
  promptWhenEmpty = true,
}: {
  enabled?: boolean;
  /**
   * Whether to fall back to "Have a test coming up?" when this learner has no
   * plan. Home passes false: the front door directly above it carries a full
   * "I have a test" tile, and the same invitation twice in a row is one
   * invitation and one piece of clutter. A surface without its own test-prep
   * entry leaves this at the default and keeps the prompt.
   */
  promptWhenEmpty?: boolean;
}) {
  const [state, setState] = useState<'loading' | 'none' | 'loaded'>('loading');
  const [plan, setPlan] = useState<Loaded | null>(null);

  useEffect(() => {
    if (!enabled) {
      setState('none');
      return;
    }
    let cancelled = false;

    (async () => {
      try {
        const saved = await api.testPrep.state();
        const current = saved?.plan;
        if (!current) {
          if (!cancelled) setState('none');
          return;
        }

        // Settled rather than all: a failing readiness call must not hide a
        // plan that exists, and neither figure may be replaced by a stand-in.
        const [readinessResult, sessionsResult] = await Promise.allSettled([
          api.testPrep.readiness(current.id),
          api.testPrep.todaySessions(),
        ]);

        const readiness: ReadinessPayload | undefined =
          readinessResult.status === 'fulfilled' ? readinessResult.value : undefined;
        const sessions: StudySessionRow[] =
          sessionsResult.status === 'fulfilled' ? sessionsResult.value ?? [] : [];
        const soonest = openSessions(sessions)[0] as StudySessionRow | undefined;

        if (cancelled) return;
        setPlan({
          // The readiness payload names the subject; the plan summary does
          // not carry one, so a failed readiness call leaves this null and
          // the card falls back to its own label rather than inventing a
          // subject the learner never typed.
          subject: readiness?.subject?.trim() || null,
          days: daysLabel(readiness?.days_remaining),
          headline: readinessHeadline(readiness),
          assessed: numberOrNull(readiness?.topics_assessed),
          total: numberOrNull(readiness?.topics_total),
          next: soonest
            ? {
                topic: String(soonest.topic ?? '').trim(),
                minutes: numberOrNull(soonest.duration_minutes),
              }
            : null,
          stale: readinessResult.status === 'rejected',
        });
        setState('loaded');
      } catch {
        // A failed lookup is not the same as "no test". The prompt below is
        // true in both cases, so it is what a failure falls back to.
        if (!cancelled) setState('none');
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [enabled]);

  if (state === 'loading') {
    // Nothing is promised while loading when the empty result renders nothing:
    // a skeleton that resolves to blank space is a card that was never there.
    if (!promptWhenEmpty) return null;
    return <div className="h-[104px] animate-pulse rounded-[17px] bg-white/[0.045]" />;
  }

  if (state === 'none' || !plan) return promptWhenEmpty ? <TestPrepPrompt /> : null;

  const { headline } = plan;
  const measured = headline.kind === 'measured' && typeof headline.percent === 'number';
  const circumference = 2 * Math.PI * 21;

  return (
    <Link
      href="/test-prep"
      className="block rounded-[17px] border border-[#F59E0B]/25 bg-gradient-to-br from-[#F59E0B]/[0.12] to-white/[0.045] p-3.5 transition-colors duration-200 hover:border-[#F59E0B]/40"
    >
      <div className="flex items-center gap-3">
        <div className="relative h-[52px] w-[52px] shrink-0">
          <svg viewBox="0 0 52 52" className="h-full w-full -rotate-90" aria-hidden="true">
            <circle cx="26" cy="26" r="21" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="4" />
            {measured && (
              <circle
                cx="26"
                cy="26"
                r="21"
                fill="none"
                stroke="#EFA43C"
                strokeWidth="4"
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={circumference * (1 - (headline.percent as number) / 100)}
              />
            )}
          </svg>
          <span className="absolute inset-0 grid place-items-center">
            {measured ? (
              <span className="font-rounded text-[16px] font-bold tabular-nums text-white">
                {headline.percent}
                <span className="align-top text-[8px] font-semibold text-white/50">%</span>
              </span>
            ) : (
              <Calendar size={17} className="text-[#EFA43C]" />
            )}
          </span>
        </div>

        <div className="min-w-0 flex-1">
          <p className="font-rounded text-[14px] font-bold leading-tight text-white line-clamp-2">
            {plan.subject || 'Test prep'}
          </p>
          <p className={`mt-0.5 text-[11px] ${plan.stale ? 'text-white/50' : 'text-white/[0.62]'}`}>
            {secondaryLine(plan)}
          </p>
        </div>

        {plan.days && (
          <span className="shrink-0 rounded-md border border-[#F59E0B]/30 bg-[#F59E0B]/[0.14] px-1.5 py-0.5 text-[9.5px] font-bold tabular-nums text-[#EFA43C]">
            {plan.days}
          </span>
        )}
      </div>

      {plan.next && (
        <div className="mt-3 flex items-center gap-2 border-t border-white/[0.08] pt-2.5">
          <span className="grid h-[25px] w-[25px] shrink-0 place-items-center rounded-full border border-white/[0.12] bg-white/[0.08]">
            <Play size={10} className="fill-current text-white" />
          </span>
          <span className="truncate text-[11.5px] font-semibold text-white">
            {nextLabel(plan.next)}
          </span>
          <ChevronRight size={12} className="ml-auto shrink-0 text-white/35" />
        </div>
      )}
    </Link>
  );
}

function TestPrepPrompt() {
  return (
    <Link
      href="/test-prep"
      className="flex items-center gap-3 rounded-[17px] border border-white/[0.07] bg-white/[0.05] px-3.5 py-3 transition-colors duration-200 hover:bg-white/[0.08]"
    >
      <span className="grid h-[30px] w-[30px] shrink-0 place-items-center rounded-[10px] bg-[#F59E0B]/[0.12]">
        <Calendar size={14} className="text-[#F59E0B]" />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[12.5px] font-semibold text-white">Have a test coming up?</span>
        <span className="block truncate text-[10.5px] text-white/[0.52]">
          Tell me what and when — I&apos;ll plan it with you
        </span>
      </span>
      <ChevronRight size={12} className="shrink-0 text-white/35" />
    </Link>
  );
}

function secondaryLine(plan: Loaded): string {
  if (plan.stale) return 'Last known reading — refresh failed';
  if (plan.headline.kind === 'measured') {
    if (plan.assessed !== null && plan.total !== null) {
      return `${plan.assessed} of ${plan.total} topics assessed`;
    }
    return 'Readiness measured';
  }
  if (plan.headline.kind === 'unmeasured') return 'Nothing assessed yet — start a session';
  return 'No topics to measure yet';
}

/**
 * The planned length travels with the topic, because the Test Prep page
 * promises it. A non-positive length is left out rather than printed as
 * "0 min".
 */
function nextLabel(next: { topic: string; minutes: number | null }): string {
  const minutes = next.minutes !== null && next.minutes > 0 ? next.minutes : null;
  if (minutes && next.topic) return `Next: ${minutes} min · ${next.topic}`;
  if (minutes) return `Next: ${minutes} min`;
  return next.topic ? `Next: ${next.topic}` : 'Next session';
}

function numberOrNull(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}
