'use client';

import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';

// Chat, classroom and the Discover reel own their own full-bleed layouts
// (iOS overlay / DiscoverView parity), so they opt out of the shell's page
// padding and max-width.
const IMMERSIVE_ROUTES = ['/chat', '/classroom', '/discover'];
// The Community map is full-bleed; its detail and editor pages are not.
const IMMERSIVE_EXACT_ROUTES = ['/community'];

// Workspace routes: still inside the shell, still padded, but not squeezed
// into a reading column. Test Prep is a two-column workspace — a KPI strip, a
// week timeline and a materials library — and the 1440px cap left it floating
// in a void on a wide monitor, which is what made a desktop app look like a
// phone app in a browser. They keep the horizontal padding, so nothing is
// flush against the window edge, and mobile is untouched.
const WIDE_ROUTES = ['/test-prep'];

export default function MainContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isImmersive =
    IMMERSIVE_ROUTES.some((r) => pathname.startsWith(r)) || IMMERSIVE_EXACT_ROUTES.includes(pathname);

  if (isImmersive) {
    return <main className="flex-1 min-h-0 overflow-hidden">{children}</main>;
  }

  const isWide = WIDE_ROUTES.some((r) => pathname.startsWith(r));

  return (
    <main className="flex-1 overflow-y-auto p-4 md:p-6 pb-28 md:pb-6">
      <div className={cn('mx-auto w-full', isWide ? 'max-w-none' : 'max-w-[1440px]')}>{children}</div>
    </main>
  );
}
