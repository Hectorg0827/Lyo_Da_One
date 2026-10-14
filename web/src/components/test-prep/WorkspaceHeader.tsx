'use client';

import { CalendarDays, ChevronDown, ChevronRight, Clock, Flame, Pencil, Plus, Target } from 'lucide-react';

import { cn } from '@/lib/utils';
import type { Kpi, KpiTone } from '@/lib/test-prep-view.mjs';
import type { PrepProfile } from '@/lib/test-prep-api';

/**
 * The workspace bar: breadcrumb, test switcher and actions, then the KPI strip.
 *
 * This replaces a bare `<select>` floating above an `<h1>`. The switcher is
 * still a native select — it is a list of the learner's own tests and every
 * alternative is a worse keyboard and screen-reader story — but it is styled
 * as the breadcrumb's last crumb, with the chevron drawn behind it.
 *
 * Switching is navigation, never modification: it must not touch the plan it
 * is leaving. That rule lives in the page; this component only reports the
 * choice.
 */

const ICONS = { calendar: CalendarDays, target: Target, flame: Flame, clock: Clock } as const;

// `muted` is the one that matters: it is what a tile shows when nothing was
// measured, and it must never be mistaken for a reading of zero.
const TONES: Record<KpiTone, string> = {
  plain: 'text-white',
  good: 'text-emerald-300',
  warn: 'text-amber-300',
  urgent: 'text-rose-300',
  muted: 'text-white/70',
};

const ICON_TONES: Record<KpiTone, string> = {
  plain: 'text-lyo-300',
  good: 'text-emerald-400',
  warn: 'text-amber-400',
  urgent: 'text-rose-400',
  muted: 'text-white/40',
};

export interface WorkspaceHeaderProps {
  subject: string;
  profiles: PrepProfile[];
  selectedProfileId: string;
  onSelectProfile: (id: string) => void;
  onNewTest: () => void;
  onEditDetails?: (() => void) | undefined;
  editing?: boolean | undefined;
  busy: boolean;
  startingNew: boolean;
  startError?: string | null | undefined;
  kpis: Kpi[];
}

export function WorkspaceHeader({
  subject,
  profiles,
  selectedProfileId,
  onSelectProfile,
  onNewTest,
  onEditDetails,
  editing,
  busy,
  startingNew,
  startError,
  kpis,
}: WorkspaceHeaderProps) {
  return (
    <header className="overflow-hidden rounded-[22px] border border-white/10 bg-gradient-to-br from-white/[0.06] to-white/[0.025] shadow-[0_6px_12px_rgba(0,0,0,0.18)]">
      {/* The page's heading is the test. It is the switcher that shows it
          visually, and a `<select>` cannot be an `<h1>`, so the heading is
          here and silent: screen readers still get "Algebra, heading level 1"
          before the combobox, rather than a page with no heading at all. */}
      <h1 className="sr-only">{subject}</h1>

      {/* ── Breadcrumb ── */}
      <nav aria-label="Breadcrumb" className="flex items-center gap-2 px-5 pt-3 sm:px-6">
        <span className="text-[13px] text-white/50">Test prep</span>
        <ChevronRight className="h-3.5 w-3.5 shrink-0 text-white/30" aria-hidden />
        <span className="truncate text-[13px] font-medium text-white/85">{subject}</span>
      </nav>

      {/* ── Toolbar ── */}
      <div className="flex flex-wrap items-center gap-2.5 px-5 pb-4 pt-3 sm:px-6">
        {profiles.length > 0 ? (
          <div className="relative min-w-0 flex-1 sm:flex-initial">
            <select
              aria-label="Choose a test"
              value={selectedProfileId}
              disabled={busy}
              onChange={(event) => onSelectProfile(event.target.value)}
              className={cn(
                'w-full min-h-[44px] cursor-pointer appearance-none truncate rounded-2xl border border-white/15',
                'bg-white/[0.06] py-2.5 pl-3.5 pr-10 font-rounded text-base font-bold text-white',
                'outline-none transition hover:bg-white/[0.09] focus-visible:border-lyo-400 disabled:opacity-50',
                'sm:max-w-[420px]',
              )}
            >
              {profiles.map((profile) => (
                <option key={profile.id} value={profile.id} className="bg-gray-900 font-sans text-sm">
                  {profile.subject === 'Pending Test' ? 'New test (in progress)' : profile.subject}
                  {profile.test_date && profile.subject !== 'Pending Test' ? ` — ${profile.test_date}` : ''}
                </option>
              ))}
            </select>
            <ChevronDown
              className="pointer-events-none absolute right-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-white/55"
              aria-hidden
            />
          </div>
        ) : (
          <p className="min-w-0 truncate font-rounded text-xl font-bold text-white">{subject}</p>
        )}

        <span className="flex-1" />

        <button
          type="button"
          onClick={onNewTest}
          disabled={busy}
          aria-label={startingNew ? 'Starting new test' : 'Create new test'}
          className={cn(
            'inline-flex min-h-[44px] items-center gap-2 rounded-2xl px-4 py-2.5',
            'bg-gradient-to-r from-lyo-600 to-lyo-400 text-sm font-semibold text-white',
            'shadow-lg shadow-lyo-600/25 transition hover:shadow-lyo-500/40 disabled:opacity-50',
          )}
        >
          <Plus className="h-4 w-4" aria-hidden />
          <span className="hidden sm:inline">{startingNew ? 'Starting…' : 'Create new test'}</span>
        </button>

        {onEditDetails && (
          <button
            type="button"
            onClick={onEditDetails}
            disabled={busy}
            aria-expanded={editing ?? false}
            aria-label={editing ? 'Close test details' : 'Edit test details'}
            className={cn(
              'inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border transition disabled:opacity-50',
              editing
                ? 'border-lyo-400/50 bg-lyo-500/20 text-white'
                : 'border-white/15 text-white/75 hover:bg-white/[0.07]',
            )}
          >
            <Pencil className="h-4 w-4" aria-hidden />
          </button>
        )}
      </div>

      {startError && (
        <p role="alert" className="px-5 pb-4 text-xs text-amber-200 sm:px-6">
          {startError}
        </p>
      )}

      {/* ── KPI strip ── */}
      <div className="grid grid-cols-2 border-t border-white/[0.08] bg-white/[0.02] lg:grid-cols-4">
        {kpis.map((kpi) => {
          const Icon = ICONS[kpi.icon];
          return (
            <div
              key={kpi.key}
              data-kpi={kpi.key}
              className={cn(
                'border-white/[0.07] px-5 py-4 sm:px-6',
                // The strip is 2x2 on a phone and one row on a desktop, so the
                // dividers follow the grid rather than assume four columns:
                // no right border on the last column, no bottom border on the
                // last row, at each breakpoint.
                'border-b border-r',
                '[&:nth-child(2n)]:border-r-0 [&:nth-child(n+3)]:border-b-0',
                'lg:[&:nth-child(2n)]:border-r lg:[&:nth-child(4n)]:border-r-0 lg:[&:nth-child(n+1)]:border-b-0',
              )}
            >
              <div className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.14em] text-white/50">
                <Icon className={cn('h-3.5 w-3.5 shrink-0', ICON_TONES[kpi.tone])} aria-hidden />
                {kpi.label}
              </div>
              <p
                className={cn(
                  'mt-1.5 font-rounded text-2xl font-extrabold leading-tight xl:text-[28px]',
                  TONES[kpi.tone],
                )}
              >
                {kpi.value}
              </p>
              <p className="mt-0.5 text-xs text-white/50">{kpi.detail}</p>
            </div>
          );
        })}
      </div>
    </header>
  );
}
