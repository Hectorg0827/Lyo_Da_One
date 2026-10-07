'use client';

import Link from 'next/link';
import { BookOpen, ChevronRight, Clock, Trophy, Zap } from 'lucide-react';
import { buildLearnerStats } from '@/lib/learner-stats.mjs';

/**
 * What this learner knows, in one of two shapes.
 *
 * `strip` is a single row — four values, four words, tappable. It is what
 * Focus shows. Four cards in a 2x2 grid took a third of a phone screen to say
 * numbers nobody reads twice, directly above the page's real content.
 *
 * `grid` is the full version: icon, value, label, the sub-line that says what
 * the word means ("applied, transferred, retained" is the whole reason
 * "Mastered" can be trusted), and the trend. It lives on Profile, which is
 * where someone goes when the numbers are what they came for.
 *
 * Both read `buildLearnerStats`, so the strip and the grid cannot drift into
 * disagreeing about the same learner.
 */

const ICONS = {
  book: BookOpen,
  trophy: Trophy,
  zap: Zap,
  clock: Clock,
} as const;

type Stat = {
  key: string;
  label: string;
  short: string;
  value: string;
  sub: string;
  icon: keyof typeof ICONS;
  color: string;
  trend: string;
};

type Payload = {
  conceptSummary?: unknown;
  gamification?: unknown;
  user?: unknown;
};

export default function LearnerStats({
  variant,
  href,
  ...payload
}: Payload & {
  variant: 'strip' | 'grid';
  /** Where the strip taps through to. Omit for a strip that isn't a link. */
  href?: string;
}) {
  const { stats } = buildLearnerStats(payload) as { stats: Stat[] };
  if (variant === 'grid') return <StatGrid stats={stats} />;

  const strip = <StatStrip stats={stats} linked={Boolean(href)} />;
  return href ? (
    <Link href={href} className="block" aria-label="See your full stats">
      {strip}
    </Link>
  ) : (
    strip
  );
}

/** One row. Value and label only — the sub-lines live on the grid. */
function StatStrip({ stats, linked }: { stats: Stat[]; linked: boolean }) {
  return (
    <div
      className={[
        'flex items-stretch rounded-2xl border border-white/[0.07] bg-white/[0.045] px-1.5 py-2.5',
        linked ? 'transition-colors duration-200 hover:bg-white/[0.08]' : '',
      ].join(' ')}
    >
      {stats.map((stat, index) => (
        <div
          key={stat.key}
          className="min-w-0 flex-1 px-1 text-center"
          style={{
            borderRight:
              index < stats.length - 1 ? '1px solid rgba(255,255,255,0.08)' : 'none',
          }}
        >
          <span
            className="block font-rounded text-[17px] font-black leading-none tabular-nums"
            style={{ color: stat.color }}
          >
            {stat.value}
          </span>
          <span className="mt-1 block truncate text-[10px] font-medium text-white/55">
            {stat.short}
          </span>
        </div>
      ))}
      {linked && (
        <span className="grid shrink-0 place-items-center pl-0.5 pr-1">
          <ChevronRight size={13} className="text-white/30" />
        </span>
      )}
    </div>
  );
}

/** The full read: what each number is, and what it took to earn it. */
function StatGrid({ stats }: { stats: Stat[] }) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {stats.map((stat) => {
        const Icon = ICONS[stat.icon] ?? BookOpen;
        return (
          <div key={stat.key} className="glass-card space-y-2 p-4">
            <div
              className="flex h-8 w-8 items-center justify-center rounded-lg"
              style={{ backgroundColor: `${stat.color}20` }}
            >
              <Icon size={16} style={{ color: stat.color }} />
            </div>
            <div>
              <p className="text-xl font-black leading-none text-primary tabular-nums">
                {stat.value}
              </p>
              <p className="mt-0.5 text-[11px] text-secondary">{stat.label}</p>
              <p className="mt-0.5 text-[10px] leading-snug text-white/40">{stat.sub}</p>
            </div>
            {stat.trend && (
              <p className="text-[10px] font-medium" style={{ color: stat.color }}>
                {stat.trend}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}
