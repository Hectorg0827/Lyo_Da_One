import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';

type BadgeVariant = 'default' | 'primary' | 'success' | 'warning' | 'danger' | 'info';
type BadgeSize = 'sm' | 'md';

interface BadgeProps {
  variant?: BadgeVariant;
  size?: BadgeSize;
  children: ReactNode;
  className?: string;
}

const variantClasses: Record<BadgeVariant, string> = {
  default:
    'bg-[var(--surface-2)] text-[var(--text-secondary)] border border-[var(--border)]',
  primary:
    'bg-[#6c63ff]/20 text-[#8b83ff] border border-[#6c63ff]/30',
  success:
    'bg-green-500/15 text-green-400 border border-green-500/25',
  warning:
    'bg-amber-500/15 text-amber-400 border border-amber-500/25',
  danger:
    'bg-red-500/15 text-red-400 border border-red-500/25',
  info:
    'bg-blue-500/15 text-blue-400 border border-blue-500/25',
};

const sizeClasses: Record<BadgeSize, string> = {
  sm: 'px-2 py-0.5 text-[10px] font-semibold',
  md: 'px-2.5 py-1 text-xs font-semibold',
};

export function Badge({ variant = 'default', size = 'md', children, className }: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full leading-none',
        variantClasses[variant],
        sizeClasses[size],
        className,
      )}
    >
      {children}
    </span>
  );
}

export default Badge;
