'use client';

import Link from 'next/link';
import { Check, ChevronRight, Clock, FileText, Play, Sparkles, Target } from 'lucide-react';

import { cn } from '@/lib/utils';
import { actionLabel, missionEntryHref, readinessExplanation, readinessLabel } from '@/lib/coach.mjs';
import { missionChecklist, readinessRing } from '@/lib/test-prep-view.mjs';
import type { CoachMissionItem, CoachReadiness } from '@/lib/coach-api';
import type { StudySessionRow } from '@/types';

/**
 * The Lyo Coach hero: where the learner stands, and the three things to do
 * about it today.
 *
 * The ring is the one piece worth being careful about. A learner with nothing
 * assessed gets no arc and no figure — a dashed empty track and the words
 * "Not measured" — because an arc drawn at zero makes exactly the claim that
 * `test-prep.mjs` exists to refuse: that they were measured and scored
 * nothing. The same rule decides the headline.
 */

const RADIUS = 72;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

export interface CoachHeroProps {
  coachReadiness?: CoachReadiness | undefined;
  mission: CoachMissionItem[];
  sessions: StudySessionRow[];
  coachFailed: boolean;
  /** The first step's entry point, for the hero's own call to action. */
  materialsByConcept?: Record<string, string> | undefined;
}

export function CoachHero({
  coachReadiness,
  mission,
  sessions,
  coachFailed,
  materialsByConcept,
}: CoachHeroProps) {
  const ring = readinessRing(coachReadiness, null);
  const steps = missionChecklist(mission, sessions);
  const totalMinutes = steps.reduce((sum, item) => sum + (item.estimated_minutes ?? 0), 0);
  const firstOpen = steps.find((step) => !step.done);
  const firstHref = firstOpen ? missionEntryHref(firstOpen) : null;

  const headline = coachReadiness
    ? ring.kind === 'measured'
      ? readinessLabel(coachReadiness)
      : 'Ready to start'
    : 'Your plan is ready';

  return (
    <section className="rounded-[22px] border border-lyo-400/25 bg-[linear-gradient(140deg,rgba(139,92,246,0.16)_0%,rgba(99,102,241,0.08)_45%,rgba(255,255,255,0.025)_100%)] p-6 shadow-[0_6px_18px_rgba(0,0,0,0.22)] sm:p-7">
      <div className="flex items-center gap-3">
        <Sparkles className="h-4 w-4 shrink-0 text-lyo-300" aria-hidden />
        <span className="text-[11px] font-semibold uppercase tracking-[0.2em] text-lyo-300/85">Lyo Coach</span>
        <span className="flex-1" />
        {totalMinutes > 0 && (
          <span className="shrink-0 rounded-full border border-white/12 px-3 py-1 text-xs text-white/65">
            {totalMinutes} min today
          </span>
        )}
      </div>

      <h2 className="mt-1.5 font-rounded text-[30px] font-extrabold leading-[1.1] text-white sm:text-4xl">
        {headline}
      </h2>

      <div className="mt-5 flex flex-wrap items-stretch gap-6">
        {/* ── Ring ── */}
        <div className="relative h-[168px] w-[168px] shrink-0">
          <svg
            viewBox="0 0 168 168"
            className="h-full w-full"
            role="img"
            aria-label={
              ring.kind === 'measured'
                ? `Readiness ${ring.percent}% — ${headline}`
                : 'Readiness not measured yet'
            }
          >
            <defs>
              <linearGradient id="coach-ring" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#6366f1" />
                <stop offset="55%" stopColor="#8b5cf6" />
                <stop offset="100%" stopColor="#34d399" />
              </linearGradient>
            </defs>
            <circle
              cx="84"
              cy="84"
              r={RADIUS}
              fill="none"
              stroke="rgba(255,255,255,0.1)"
              strokeWidth="12"
              {...(ring.kind === 'measured' ? {} : { strokeDasharray: '3 9', strokeLinecap: 'round' as const })}
            />
            {ring.kind === 'measured' && (
              <circle
                cx="84"
                cy="84"
                r={RADIUS}
                fill="none"
                stroke="url(#coach-ring)"
                strokeWidth="12"
                strokeLinecap="round"
                strokeDasharray={CIRCUMFERENCE}
                strokeDashoffset={CIRCUMFERENCE * (1 - ring.percent / 100)}
                transform="rotate(-90 84 84)"
              />
            )}
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            {ring.kind === 'measured' ? (
              <>
                <span className="font-rounded text-[42px] font-extrabold leading-none text-white">
                  {ring.percent}%
                </span>
                <span className="text-[11px] font-semibold uppercase tracking-[0.12em] text-white/55">
                  Evidence
                </span>
              </>
            ) : (
              <>
                <Sparkles className="h-9 w-9 text-lyo-300/80" aria-hidden />
                <span className="mt-2 max-w-[110px] text-center text-[11px] font-semibold uppercase tracking-[0.1em] text-white/50">
                  Not measured
                </span>
              </>
            )}
          </div>
        </div>

        {/* ── Explanation + CTA ── */}
        <div className="flex min-w-0 flex-1 basis-[300px] flex-col justify-center rounded-[18px] border border-white/10 bg-black/20 p-5 sm:p-6">
          <p className="font-rounded text-xl font-bold text-white sm:text-[22px]">
            {coachReadiness && coachReadiness.total_skills > 0
              ? `${coachReadiness.assessed_skills} of ${coachReadiness.total_skills} skills shown`
              : 'No skill assessed yet'}
          </p>
          <p className="mt-2 max-w-[60ch] text-sm leading-6 text-white/75">
            {readinessExplanation(coachReadiness)}
          </p>
          <p className="mt-2 max-w-[60ch] text-xs leading-5 text-white/[0.48]">
            Based on demonstrated evidence, not a predicted exam grade.
          </p>
          {coachFailed && (
            <p className="mt-2 text-xs text-amber-200">This mission may not include your latest evidence.</p>
          )}
          {firstHref && (
            <Link
              href={firstHref}
              className="mt-4 inline-flex min-h-[44px] items-center gap-2 self-start rounded-2xl bg-gradient-to-b from-white to-sky-50 px-5 py-3 text-sm font-bold text-violet-700 shadow-[0_5px_12px_rgba(0,0,0,0.2)] transition hover:to-white"
            >
              <Play className="h-4 w-4 fill-current" aria-hidden />
              Start today&rsquo;s mission
            </Link>
          )}
        </div>
      </div>

      {/* ── The mission ── */}
      {steps.length > 0 && (
        <div className="mt-6 border-t border-white/10 pt-5">
          <div className="flex flex-wrap items-end gap-3">
            <div className="min-w-0 flex-1">
              <h3 className="font-rounded text-xl font-bold text-white">Today&rsquo;s Mission</h3>
              <p className="mt-0.5 text-[13px] text-white/55">
                {steps.length} {steps.length === 1 ? 'step' : 'steps'}, aimed at your weakest topics first.
              </p>
            </div>
          </div>

          <ol className="mt-4 flex flex-col gap-2.5">
            {steps.map((step, index) => (
              <MissionStep
                key={step.skill_id ?? `${step.concept_id}-${index}`}
                step={step}
                index={index}
                expanded={step === firstOpen}
                material={step.concept_id ? materialsByConcept?.[step.concept_id] : undefined}
              />
            ))}
          </ol>
        </div>
      )}
    </section>
  );
}

function MissionStep({
  step,
  index,
  expanded,
  material,
}: {
  step: CoachMissionItem & { done: boolean };
  index: number;
  expanded: boolean;
  material?: string | undefined;
}) {
  const href = missionEntryHref(step);
  const critical = (step.priority_score ?? 0) >= 0.8;

  return (
    <li
      className={cn(
        'overflow-hidden rounded-[18px] border bg-black/[0.18]',
        expanded ? 'border-lyo-300/35 bg-black/20' : 'border-white/12',
      )}
    >
      <div className="flex items-center gap-3 p-4">
        {/* A status marker, not a checkbox: there is no endpoint to tick a
            mission step off, and a control that forgets itself on refresh is
            worse than none. A step reads done when a session for the same
            concept is done. */}
        <span
          className={cn(
            'flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-[13px] font-bold',
            step.done ? 'bg-emerald-500/20 text-emerald-300' : 'bg-white/12 text-white',
          )}
          aria-hidden
        >
          {step.done ? <Check className="h-4 w-4" strokeWidth={3} /> : index + 1}
        </span>

        <div className="min-w-0 flex-1">
          <p
            className={cn(
              'truncate text-[15px] font-semibold sm:text-base',
              step.done ? 'text-white/65 line-through' : 'text-white',
            )}
          >
            {step.title}
          </p>
          <p className="mt-0.5 truncate text-[13px] text-white/[0.58]">
            {step.done ? 'Done' : actionLabel(step.action)} &middot; {step.estimated_minutes} min
          </p>
        </div>

        {critical && !step.done && (
          <span className="hidden shrink-0 rounded-lg bg-rose-500/[0.18] px-2.5 py-1 text-[11px] font-semibold text-rose-300 sm:inline">
            Critical gap
          </span>
        )}

        {href ? (
          <Link
            href={href}
            className={cn(
              'inline-flex min-h-[36px] shrink-0 items-center rounded-xl px-4 py-2 text-[13px] font-semibold transition',
              step.done
                ? 'border border-white/15 text-white/70 hover:bg-white/[0.07]'
                : expanded
                  ? 'bg-gradient-to-r from-lyo-600 to-lyo-400 text-white shadow-md shadow-lyo-600/25'
                  : 'border border-white/15 text-white/85 hover:bg-white/[0.07]',
            )}
          >
            {step.done ? 'Again' : 'Start'}
          </Link>
        ) : (
          <ChevronRight className="h-4 w-4 shrink-0 text-white/30" aria-hidden />
        )}
      </div>

      {/* Details sit open on the step the learner is actually on. Everything
          in here comes from the mission item itself — nothing is invented to
          fill the panel. */}
      {expanded && (
        <div className="px-4 pb-4">
          <p className="border-t border-white/[0.08] py-2.5 text-[11px] font-semibold uppercase tracking-[0.1em] text-white/50">
            Details
          </p>
          <div className="flex flex-wrap gap-2.5">
            <DetailTile icon={Clock} label="Takes" value={`${step.estimated_minutes} minutes`} />
            <DetailTile icon={Target} label="Why this" value={step.reason || actionLabel(step.action)} />
            {material && <DetailTile icon={FileText} label="Uses your material" value={material} />}
          </div>
        </div>
      )}
    </li>
  );
}

function DetailTile({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Clock;
  label: string;
  value: string;
}) {
  return (
    <div className="min-w-0 flex-1 basis-[180px] rounded-[13px] border border-white/10 bg-white/[0.04] px-3.5 py-3">
      <div className="flex items-center gap-1.5 text-[11px] text-white/50">
        <Icon className="h-3.5 w-3.5 shrink-0" aria-hidden />
        {label}
      </div>
      <p className="mt-1 text-[15px] font-semibold text-white">{value}</p>
    </div>
  );
}
