'use client';

import Link from 'next/link';
import { Film, Loader2 } from 'lucide-react';
import { useApi } from '@/hooks/use-api';
import { api } from '@/lib/api';
import { formatNumber } from '@/lib/utils';
import {
  METRICS,
  METRIC_LABELS,
  coverageNote,
  creatorStats,
  isReported,
} from '@/lib/creator-stats.mjs';

/**
 * A creator's own clips, and what they have added up to.
 *
 * The economy comes later; this is the part that has to exist first. Nobody
 * keeps making videos for a feed that never tells them whether anyone
 * watched, and until now nothing in the product showed a creator a single
 * number about their own work.
 *
 * What it will not do is make a figure up. Every count on a clip is optional,
 * so a total says how much of the library it actually covers, and a metric no
 * clip reported reads "Not reported" rather than 0 — a creator whose views
 * are not being counted needs to know that, not be told nobody watched. The
 * branching lives in `creator-stats.mjs`, which is unit-tested.
 */
/** The shapes `creator-stats.mjs` returns, named for TypeScript's benefit. */
type Metric = 'views' | 'likes' | 'comments' | 'shares';
type Total = { metric: Metric; value: number; reporting: number; clips: number };

const metrics = METRICS as readonly Metric[];
const labels = METRIC_LABELS as Record<Metric, string>;

export default function CreatorStatsPanel() {
  const { data, isLoading } = useApi(() => api.clips.list(1, 50), []);

  if (isLoading) {
    return (
      <div className="glass-card flex justify-center px-5 py-10">
        <Loader2 className="h-5 w-5 animate-spin text-lyo-500" />
      </div>
    );
  }

  const clips = (data?.clips as Record<string, unknown>[]) || [];
  const { clipCount, totals } = creatorStats(clips) as {
    clipCount: number;
    totals: Record<Metric, Total>;
  };

  if (clipCount === 0) {
    return (
      <div className="glass-card px-5 py-10 text-center">
        <Film className="mx-auto mb-3 text-white/25" />
        <p className="text-sm font-medium text-white/70">No clips yet</p>
        <p className="mx-auto mt-1 max-w-xs text-xs text-white/40">
          Teach something in 60 seconds and it shows up here — with how many people watched it.
        </p>
        <Link
          href="/discover?compose=clip"
          className="mt-4 inline-flex rounded-full bg-white px-4 py-2 font-rounded text-[13px] font-bold text-[#0A0D16]"
        >
          Make your first clip
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {metrics.map((metric) => {
          const total = totals[metric];
          const note = coverageNote(total);
          return (
            <div key={metric} className="glass-card p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.1em] text-white/45">
                {labels[metric]}
              </p>
              {isReported(total) ? (
                <p className="mt-1 font-rounded text-[22px] font-bold tabular-nums text-white">
                  {formatNumber(total.value)}
                </p>
              ) : (
                /* Not a zero. No clip reported this figure, and telling a
                   creator nobody watched would be a different claim. */
                <p className="mt-1 text-[13px] font-semibold text-white/45">Not reported</p>
              )}
              {note && <p className="mt-0.5 text-[10px] text-white/40">{note}</p>}
            </div>
          );
        })}
      </div>

      <p className="px-1 text-xs text-white/45 tabular-nums">
        {clipCount === 1 ? '1 clip' : `${clipCount} clips`}
      </p>

      <div className="space-y-2">
        {clips.map((raw, index) => {
          const id = String(raw.id ?? index);
          const views = (raw.viewCount ?? raw.view_count) as number | null | undefined;
          return (
            <Link
              key={id}
              href={`/discover?clip=${encodeURIComponent(id)}`}
              className="glass-card flex items-center gap-3 p-3 transition-colors hover:bg-white/[0.07]"
            >
              <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-[#8B5CF6]/15 text-[#B59CFF]">
                <Film size={16} />
              </div>
              <p className="min-w-0 flex-1 truncate text-sm font-semibold text-white">
                {String(raw.title ?? 'Untitled clip')}
              </p>
              <span className="shrink-0 text-[11px] tabular-nums text-white/45">
                {typeof views === 'number' ? `${formatNumber(views)} views` : 'Views not reported'}
              </span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
