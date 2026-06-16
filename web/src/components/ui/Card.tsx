import React, { ReactNode } from 'react';
import { cn } from '@/lib/utils';

type CardVariant = 'default' | 'glass' | 'outlined';

interface CardProps {
  variant?: CardVariant;
  hover?: boolean;
  className?: string;
  children: ReactNode;
  onClick?: () => void;
}

const variantClasses: Record<CardVariant, string> = {
  default:
    'bg-[var(--surface)] border border-[var(--border)]',
  glass:
    'backdrop-blur-md bg-white/5 border border-white/10',
  outlined:
    'bg-transparent border border-[var(--border)]',
};

export function Card({ variant = 'default', hover = false, className, children, onClick }: CardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        'rounded-2xl transition-all duration-200',
        variantClasses[variant],
        hover && [
          'cursor-pointer',
          'hover:scale-[1.015] hover:shadow-xl hover:shadow-black/30',
          variant === 'default' && 'hover:border-[#3a3a50] hover:bg-[#131320]',
          variant === 'glass' && 'hover:bg-white/8 hover:border-white/15',
          variant === 'outlined' && 'hover:border-[#3a3a50] hover:bg-white/3',
        ],
        onClick && !hover && 'cursor-pointer',
        className,
      )}
    >
      {children}
    </div>
  );
}

export default Card;
