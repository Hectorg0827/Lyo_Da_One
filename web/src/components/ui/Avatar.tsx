import React from 'react';
import Image from 'next/image';
import { cn } from '@/lib/utils';

type AvatarSize = 'sm' | 'md' | 'lg' | 'xl';

interface AvatarProps {
  src?: string;
  name: string;
  size?: AvatarSize;
  online?: boolean;
  className?: string;
}

const sizeMap: Record<AvatarSize, { container: string; px: number; text: string; indicator: string }> = {
  sm: { container: 'w-6 h-6', px: 24, text: 'text-[9px]', indicator: 'w-1.5 h-1.5 border' },
  md: { container: 'w-8 h-8', px: 32, text: 'text-[11px]', indicator: 'w-2 h-2 border' },
  lg: { container: 'w-10 h-10', px: 40, text: 'text-[13px]', indicator: 'w-2.5 h-2.5 border-2' },
  xl: { container: 'w-14 h-14', px: 56, text: 'text-base', indicator: 'w-3.5 h-3.5 border-2' },
};

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function getGradient(name: string): string {
  const gradients = [
    'from-[#6c63ff] to-[#8b5cf6]',
    'from-[#ec4899] to-[#8b5cf6]',
    'from-[#3b82f6] to-[#6c63ff]',
    'from-[#10b981] to-[#3b82f6]',
    'from-[#f59e0b] to-[#ef4444]',
    'from-[#8b5cf6] to-[#ec4899]',
  ];
  const index = name.charCodeAt(0) % gradients.length;
  return gradients[index];
}

export function Avatar({ src, name, size = 'md', online, className }: AvatarProps) {
  const { container, px, text, indicator } = sizeMap[size];
  const initials = getInitials(name);
  const gradient = getGradient(name);

  return (
    <div className={cn('relative inline-flex shrink-0', container, className)}>
      {src ? (
        <Image
          src={src}
          alt={name}
          width={px}
          height={px}
          className={cn('rounded-full object-cover', container)}
        />
      ) : (
        <div
          className={cn(
            'rounded-full bg-gradient-to-br flex items-center justify-center font-semibold text-white select-none',
            container,
            text,
            gradient,
          )}
          aria-label={name}
        >
          {initials}
        </div>
      )}

      {online !== undefined && (
        <span
          className={cn(
            'absolute bottom-0 right-0 rounded-full border-[var(--surface)]',
            indicator,
            online ? 'bg-green-400' : 'bg-gray-500',
          )}
          aria-label={online ? 'Online' : 'Offline'}
        />
      )}
    </div>
  );
}

export default Avatar;
