'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, useInView } from 'framer-motion';
import { Users, Zap, FileText, BookOpen, TrendingUp } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { CommunityStats as CommunityStatsType } from '@/types';

// ---- Animated Counter ----
interface AnimatedCounterProps {
  target: number;
  suffix?: string;
  duration?: number;
}

function AnimatedCounter({ target, suffix = '', duration = 1.5 }: AnimatedCounterProps) {
  const [count, setCount] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const isInView = useInView(ref, { once: true });

  useEffect(() => {
    if (!isInView) return;
    let start = 0;
    const end = target;
    const increment = end / (duration * 60); // ~60fps
    const timer = setInterval(() => {
      start += increment;
      if (start >= end) {
        setCount(end);
        clearInterval(timer);
      } else {
        setCount(Math.floor(start));
      }
    }, 1000 / 60);
    return () => clearInterval(timer);
  }, [isInView, target, duration]);

  const format = (n: number) => {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toLocaleString();
  };

  return (
    <span ref={ref} className="tabular-nums">
      {format(count)}
      {suffix}
    </span>
  );
}

// ---- Stat Item ----
interface StatItemProps {
  icon: typeof Users;
  label: string;
  value: number;
  suffix?: string;
  color: string;
  delay?: number;
}

function StatItem({ icon: Icon, label, value, suffix, color, delay = 0 }: StatItemProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay, ease: 'easeOut' }}
      className="flex flex-col items-center gap-1 px-4 py-3 rounded-xl bg-white/4 border border-white/8 hover:bg-white/6 hover:border-white/12 transition-all duration-200 min-w-[110px]"
    >
      <div className={cn('p-1.5 rounded-lg mb-0.5', color)}>
        <Icon className="w-3.5 h-3.5" />
      </div>
      <span className="text-lg font-bold text-white leading-none tracking-tight">
        <AnimatedCounter target={value} suffix={suffix} />
      </span>
      <span className="text-[10px] text-white/40 font-medium text-center leading-tight">
        {label}
      </span>
    </motion.div>
  );
}

// ---- Main Component ----
interface CommunityStatsProps {
  stats: CommunityStatsType;
  className?: string;
}

const STATS_CONFIG = [
  {
    key: 'totalMembers' as const,
    icon: Users,
    label: 'Members',
    color: 'bg-blue-500/20 text-blue-400',
  },
  {
    key: 'activeToday' as const,
    icon: Zap,
    label: 'Active Today',
    color: 'bg-green-500/20 text-green-400',
  },
  {
    key: 'totalPosts' as const,
    icon: FileText,
    label: 'Total Posts',
    color: 'bg-purple-500/20 text-purple-400',
  },
  {
    key: 'totalCourses' as const,
    icon: BookOpen,
    label: 'Courses Shared',
    color: 'bg-cyan-500/20 text-cyan-400',
  },
  {
    key: 'totalClips' as const,
    icon: TrendingUp,
    label: 'Clips Created',
    color: 'bg-amber-500/20 text-amber-400',
  },
];

export default function CommunityStats({ stats, className }: CommunityStatsProps) {
  return (
    <div className={cn('w-full', className)}>
      {/* Gradient separator */}
      <div className="h-px w-full bg-gradient-to-r from-transparent via-lyo-500/30 to-transparent mb-3" />

      <div className="flex gap-3 overflow-x-auto no-scrollbar pb-1">
        {STATS_CONFIG.map((cfg, i) => (
          <StatItem
            key={cfg.key}
            icon={cfg.icon}
            label={cfg.label}
            value={stats[cfg.key]}
            color={cfg.color}
            delay={i * 0.07}
          />
        ))}
      </div>

      <div className="h-px w-full bg-gradient-to-r from-transparent via-lyo-500/30 to-transparent mt-3" />
    </div>
  );
}
