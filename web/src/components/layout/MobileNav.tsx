'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, BookOpen, Sparkles, Users, User } from 'lucide-react';
import { cn } from '@/lib/utils';

const navItems = [
  { href: '/', icon: Home, label: 'Home' },
  { href: '/courses', icon: BookOpen, label: 'Courses' },
  { href: '/chat', icon: Sparkles, label: 'LYO AI', isCenter: true },
  { href: '/community', icon: Users, label: 'Community' },
  { href: '/profile', icon: User, label: 'Profile' },
] as { href: string; icon: typeof Home; label: string; isCenter?: boolean }[];

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav
      className={cn(
        'md:hidden fixed bottom-0 left-0 right-0 z-50',
        'bg-black/80 backdrop-blur-xl border-t border-white/10',
      )}
      aria-label="Mobile navigation"
    >
      <div className="flex items-end justify-around px-2 h-16">
        {navItems.map(({ href, icon: Icon, label, isCenter }) => {
          const isActive = href === '/' ? pathname === '/' : pathname.startsWith(href);

          if (isCenter) {
            return (
              <Link
                key={href}
                href={href}
                aria-label={label}
                aria-current={isActive ? 'page' : undefined}
                className="flex flex-col items-center justify-center -mt-5"
              >
                <div
                  className={cn(
                    'w-14 h-14 rounded-2xl flex items-center justify-center',
                    'bg-gradient-to-br from-[#6c63ff] to-[#8b5cf6]',
                    'shadow-lg shadow-[#6c63ff]/40',
                    'transition-all duration-200',
                    isActive
                      ? 'scale-105 shadow-xl shadow-[#6c63ff]/50'
                      : 'hover:scale-105 active:scale-95',
                  )}
                >
                  <Icon className="w-6 h-6 text-white" />
                </div>
                <span
                  className={cn(
                    'text-[10px] font-semibold mt-1',
                    isActive ? 'text-lyo-400' : 'text-gray-500',
                  )}
                >
                  {label}
                </span>
              </Link>
            );
          }

          return (
            <Link
              key={href}
              href={href}
              aria-label={label}
              aria-current={isActive ? 'page' : undefined}
              className="flex flex-col items-center justify-center gap-1 flex-1 py-2 transition-colors"
            >
              <div
                className={cn(
                  'relative flex items-center justify-center w-8 h-8 rounded-xl transition-all duration-200',
                  isActive ? 'bg-[#6c63ff]/15' : 'bg-transparent',
                )}
              >
                <Icon
                  className={cn(
                    'w-5 h-5 transition-colors',
                    isActive ? 'text-lyo-400' : 'text-gray-500',
                  )}
                />
              </div>
              <span
                className={cn(
                  'text-[10px] font-medium',
                  isActive ? 'text-lyo-400' : 'text-gray-500',
                )}
              >
                {label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

export default MobileNav;
