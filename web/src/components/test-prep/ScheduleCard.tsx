'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { CalendarClock, Check, ChevronDown, ChevronLeft, ChevronRight } from 'lucide-react';

import { cn } from '@/lib/utils';
import { sessionEntryHref } from '@/lib/test-prep.mjs';
import { hourLabel, milestoneForWeek, planProgress, sessionDate, weekTimeline } from '@/lib/test-prep-view.mjs';
import type { PrepSnapshot } from '@/lib/test-prep-api';

/**
 * The full study schedule, as a week.
 *
 * This replaces a collapsed `<details>` holding a flat list of every session
 * the plan ever had. On a desktop the horizontal space is there, so the week
 * is drawn as a timeline: days across, hours down, each session a block in
 * the column it actually falls in.
 *
 * "The column it actually falls in" is the whole reason the arithmetic lives
 * in `test-prep-view.mjs` rather than here: the instants are UTC and the grid
 * is in the learner's study timezone, so an 8pm Tuesday session is an 01:00
 * Wednesday instant, and bucketing it by its UTC date would draw it on the
 * wrong day for half the planet.
 *
 * A 7-column grid is unreadable on a phone, so below `md` the same week is a
 * side-scrolling strip of day chips. Both are fed by one `weekTimeline` call.
 */

/** 48px per hour reads as a calendar without making a week scroll. */
const PX_PER_MINUTE = 48 / 60;
const MIN_BLOCK_PX = 22;

export function ScheduleCard({ snapshot }: { snapshot: PrepSnapshot }) {
  const [open, setOpen] = useState(true);
  const [weekOffset, setWeekOffset] = useState(0);
  const [showAll, setShowAll] = useState(false);

  const historical = snapshot.plan?.status === 'completed' || snapshot.plan?.status === 'archived';
  const timezone = snapshot.timezone;

  const timeline = useMemo(() => {
    const now = new Date();
    now.setDate(now.getDate() + weekOffset * 7);
    return weekTimeline(snapshot.sessions, { timezone, now });
  }, [snapshot.sessions, timezone, weekOffset]);

  const progress = planProgress(snapshot.sessions);
  const milestone = milestoneForWeek(
    snapshot.plan?.weekly_milestones,
    timeline.days[0]?.key,
    snapshot.sessions,
    timezone,
  );
  const gridHeight = timeline.hours.length * 48;

  return (
    <section className="rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] p-5 shadow-[0_6px_12px_rgba(0,0,0,0.18)] sm:p-[22px]">
      <div className="flex flex-wrap items-center gap-2.5">
        <button
          type="button"
          onClick={() => setOpen(!open)}
          aria-expanded={open}
          aria-label={open ? 'Collapse full study schedule' : 'Expand full study schedule'}
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/[0.07] hover:text-white"
        >
          <ChevronDown className={cn('h-4 w-4 transition-transform', open ? '' : '-rotate-90')} aria-hidden />
        </button>
        <CalendarClock className="h-4 w-4 shrink-0 text-lyo-300" aria-hidden />
        <h3 className="min-w-0 font-rounded text-lg font-bold text-white">Full Study Schedule</h3>
        <span className="flex-1" />
        {/* Only while the card is open: the list it toggles lives inside the
            open branch, so a collapsed card's button flipped its own label to
            "Hide list" while showing nothing. */}
        {open && snapshot.sessions.length > 0 && (
          <button
            type="button"
            onClick={() => setShowAll(!showAll)}
            aria-expanded={showAll}
            className="shrink-0 text-[13px] font-semibold text-lyo-300 transition hover:text-white"
          >
            {showAll ? 'Hide list' : `All ${snapshot.sessions.length} sessions`}
          </button>
        )}
      </div>

      {open && (
        <>
          {/* ── Week controls ── */}
          <div className="mt-3.5 flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-1 rounded-xl border border-white/12 bg-white/[0.04] p-1">
              <button
                type="button"
                onClick={() => setWeekOffset(weekOffset - 1)}
                aria-label="Previous week"
                className="flex h-8 w-8 items-center justify-center rounded-lg text-white/70 transition hover:bg-white/[0.08] hover:text-white"
              >
                <ChevronLeft className="h-4 w-4" aria-hidden />
              </button>
              <button
                type="button"
                onClick={() => setWeekOffset(0)}
                className="min-w-[72px] px-2 text-[13px] font-medium text-white/80 transition hover:text-white"
              >
                {weekOffset === 0 ? 'This week' : weekOffset === 1 ? 'Next week' : weekOffset === -1 ? 'Last week' : `${weekOffset > 0 ? '+' : ''}${weekOffset} weeks`}
              </button>
              <button
                type="button"
                onClick={() => setWeekOffset(weekOffset + 1)}
                aria-label="Next week"
                className="flex h-8 w-8 items-center justify-center rounded-lg text-white/70 transition hover:bg-white/[0.08] hover:text-white"
              >
                <ChevronRight className="h-4 w-4" aria-hidden />
              </button>
            </div>

            <span className="rounded-xl border border-white/10 px-3 py-2 text-[13px] text-white/60">{timezone}</span>

            <span className="flex-1" />

            <span className="flex items-center gap-3 text-[11px] text-white/50">
              <span className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-[3px] bg-lyo-400" aria-hidden />
                Scheduled
              </span>
              <span className="flex items-center gap-1.5">
                <span className="h-2.5 w-2.5 rounded-[3px] bg-emerald-500/75" aria-hidden />
                Done
              </span>
            </span>
          </div>

          {/* ── Desktop: the week as a timeline ── */}
          <div
            className="mt-3.5 hidden md:grid"
            style={{ gridTemplateColumns: '62px repeat(7, minmax(0, 1fr))' }}
          >
            <div aria-hidden />
            {timeline.days.map((day) => (
              <div key={day.key} className="pb-2 text-center">
                <span
                  className={cn(
                    'block text-[10px] font-semibold uppercase tracking-[0.08em]',
                    day.isToday ? 'text-lyo-300' : 'text-white/45',
                  )}
                >
                  {day.weekday}
                </span>
                <span
                  className={cn(
                    'block text-[13px]',
                    day.isToday ? 'font-extrabold text-white' : 'font-semibold text-white/70',
                  )}
                >
                  {day.dayOfMonth}
                </span>
              </div>
            ))}

            {/* Time gutter */}
            <div className="flex flex-col">
              {timeline.hours.map((hour) => (
                <span key={hour} className="h-12 text-[10px] text-white/[0.38]">
                  {hourLabel(hour)}
                </span>
              ))}
            </div>

            {timeline.days.map((day) => (
              <div
                key={day.key}
                className={cn(
                  'relative border-l border-white/[0.07]',
                  day.isToday && 'bg-lyo-400/[0.07]',
                  'last:border-r last:border-white/[0.07]',
                )}
                style={{
                  height: gridHeight,
                  backgroundImage:
                    'repeating-linear-gradient(to bottom, rgba(255,255,255,0.06) 0 1px, transparent 1px 48px)',
                }}
              >
                {day.blocks.map((block) => {
                  const href = historical || block.done ? null : sessionEntryHref(block.session);
                  const inner = (
                    <>
                      <span className="block truncate">{block.topic || 'Session'}</span>
                    </>
                  );
                  const className = cn(
                    'absolute left-[3px] right-[3px] overflow-hidden rounded-[7px] border-l-[3px] px-2 py-1 text-[11px]',
                    block.done
                      ? 'border-emerald-500 bg-emerald-500/[0.18] text-emerald-100/90'
                      : 'border-lyo-400 bg-lyo-400/40 font-semibold text-white',
                  );
                  const style = {
                    top: Math.max(0, block.startMinutes * PX_PER_MINUTE),
                    height: Math.max(MIN_BLOCK_PX, block.durationMinutes * PX_PER_MINUTE),
                  };
                  return href ? (
                    <Link key={block.id} href={href} className={cn(className, 'transition hover:brightness-125')} style={style}>
                      {inner}
                    </Link>
                  ) : (
                    <span key={block.id} className={className} style={style}>
                      {inner}
                    </span>
                  );
                })}
              </div>
            ))}
          </div>

          {/* ── Phone: the same week as a scrolling strip ── */}
          <div className="no-scrollbar mt-3.5 flex gap-2 overflow-x-auto pb-1 md:hidden">
            {timeline.days.map((day) => (
              <div
                key={day.key}
                className={cn(
                  'shrink-0 basis-[56px] rounded-[13px] border px-1 py-2 text-center',
                  day.isToday
                    ? 'border-lyo-400 bg-lyo-400/25'
                    : day.status === 'done'
                      ? 'border-white/[0.08] bg-emerald-500/10'
                      : day.status === 'rest'
                        ? 'border-white/[0.08] bg-white/[0.015]'
                        : 'border-white/[0.08] bg-white/[0.04]',
                )}
              >
                <span className={cn('block text-[9px] font-semibold', day.isToday ? 'text-white' : 'text-white/50')}>
                  {day.weekday.toUpperCase()}
                </span>
                <span
                  className={cn(
                    'mt-0.5 block font-rounded text-[15px]',
                    day.isToday ? 'font-extrabold text-white' : day.status === 'rest' ? 'font-bold text-white/60' : 'font-bold text-white',
                  )}
                >
                  {day.dayOfMonth}
                </span>
                {day.status === 'done' ? (
                  <Check className="mx-auto mt-1 h-3 w-3 text-emerald-400" strokeWidth={3} aria-label="Done" />
                ) : (
                  <span className={cn('mt-1 block text-[9px]', day.isToday ? 'font-bold text-white' : 'text-white/50')}>
                    {day.totalMinutes > 0 ? `${day.totalMinutes}m` : 'Rest'}
                  </span>
                )}
              </div>
            ))}
          </div>

          {/* ── Milestone + progress ── */}
          {(milestone || progress.total > 0) && (
            <div className="mt-3.5 flex flex-wrap items-center gap-2.5 rounded-2xl bg-lyo-500/[0.12] px-3.5 py-2.5">
              {milestone && (
                <>
                  <span className="shrink-0 rounded-md bg-lyo-500/30 px-2 py-0.5 text-[10px] font-bold uppercase tracking-[0.08em] text-lyo-100">
                    Week {milestone.week}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-[13px] text-lyo-100">{milestone.focus}</span>
                </>
              )}
              {progress.total > 0 && (
                <span className="shrink-0 text-xs text-white/50">
                  {progress.done} of {progress.total} sessions done
                </span>
              )}
            </div>
          )}

          {/* ── The whole plan, when asked for ── */}
          {showAll && (
            <ul className="mt-3.5 flex max-h-[420px] flex-col gap-2 overflow-y-auto pr-1">
              {snapshot.sessions.map((session) => {
                const href = sessionEntryHref(session);
                const done = session.status === 'completed';
                return (
                  <li
                    key={session.id}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-2xl bg-white/[0.05] p-3"
                  >
                    <div className="min-w-0">
                      <p className={cn('truncate text-sm', done ? 'text-white/65 line-through' : 'text-white')}>
                        {session.topic}
                      </p>
                      <p className="mt-0.5 text-xs text-white/55">
                        {sessionDate(session.scheduled_at).toLocaleString(undefined, { timeZone: timezone })}
                        {' · '}
                        {session.duration_minutes} min · {session.session_type.replace('_', ' ')}
                      </p>
                    </div>
                    {!historical && session.status === 'scheduled' && href ? (
                      <Link
                        href={href}
                        className="shrink-0 rounded-xl bg-lyo-400/25 px-3 py-2 text-[13px] font-semibold text-lyo-100 transition hover:bg-lyo-400/35"
                      >
                        Start session
                      </Link>
                    ) : (
                      <span className="shrink-0 text-[13px] text-white/55">{session.status}</span>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </>
      )}
    </section>
  );
}
