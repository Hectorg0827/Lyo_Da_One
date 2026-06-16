import React from 'react';
import { cn } from '@/lib/utils';

/* ============================================================
   Base shimmer style (applied via className with inline style)
   ============================================================ */
const shimmerBase =
  'rounded-md animate-[shimmer_1.5s_infinite_linear] [background:linear-gradient(90deg,#1a1a24_25%,#2a2a3a_50%,#1a1a24_75%)] [background-size:200%_100%]';

/* ============================================================
   SkeletonLine
   ============================================================ */
interface SkeletonLineProps {
  width?: string;
  height?: string;
  className?: string;
}

export function SkeletonLine({ width = '100%', height = '14px', className }: SkeletonLineProps) {
  return (
    <div
      className={cn(shimmerBase, className)}
      style={{ width, height }}
      aria-hidden="true"
    />
  );
}

/* ============================================================
   SkeletonCircle
   ============================================================ */
interface SkeletonCircleProps {
  size?: string;
  className?: string;
}

export function SkeletonCircle({ size = '40px', className }: SkeletonCircleProps) {
  return (
    <div
      className={cn(shimmerBase, 'rounded-full shrink-0', className)}
      style={{ width: size, height: size }}
      aria-hidden="true"
    />
  );
}

/* ============================================================
   SkeletonCard
   ============================================================ */
interface SkeletonCardProps {
  className?: string;
}

export function SkeletonCard({ className }: SkeletonCardProps) {
  return (
    <div
      className={cn(
        'bg-[var(--surface)] border border-[var(--border)] rounded-2xl p-4',
        className,
      )}
      aria-busy="true"
      aria-label="Loading..."
    >
      {/* Header row: circle + two lines */}
      <div className="flex items-center gap-3 mb-4">
        <SkeletonCircle size="40px" />
        <div className="flex-1 flex flex-col gap-2">
          <SkeletonLine width="60%" height="14px" />
          <SkeletonLine width="40%" height="12px" />
        </div>
      </div>

      {/* Body lines */}
      <div className="flex flex-col gap-2.5">
        <SkeletonLine width="100%" height="12px" />
        <SkeletonLine width="90%" height="12px" />
        <SkeletonLine width="75%" height="12px" />
      </div>

      {/* Bottom row */}
      <div className="flex items-center gap-3 mt-4 pt-4 border-t border-[var(--border)]">
        <SkeletonLine width="80px" height="28px" className="rounded-full" />
        <SkeletonLine width="60px" height="28px" className="rounded-full" />
      </div>
    </div>
  );
}
