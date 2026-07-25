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

// `default` and `glass` both use the iOS glass spec (white 6%→2.5% fill,
// white 12%→4% hairline) so cards read the same on the premium background.
const variantClasses: Record<CardVariant, string> = {
  default: 'glass-card',
  glass: 'glass-card',
  outlined: 'bg-transparent border border-white/10',
};

export function Card({ variant = 'default', hover = false, className, children, onClick }: CardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        'transition-all duration-200',
        variantClasses[variant],
        hover && [
          'cursor-pointer',
          'hover:scale-[1.015] hover:shadow-xl hover:shadow-black/30',
          variant === 'outlined' ? 'hover:border-white/20' : 'hover:border-white/20',
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
