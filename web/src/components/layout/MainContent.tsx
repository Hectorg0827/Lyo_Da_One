'use client';

import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';

// Chat owns its own full-bleed layout (iOS overlay parity), so it opts out of
// the shell's page padding and max-width.
export default function MainContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isImmersive = pathname.startsWith('/chat') || pathname.startsWith('/classroom');

  if (isImmersive) {
    return <main className="flex-1 min-h-0 overflow-hidden">{children}</main>;
  }

  return (
    <main className="flex-1 overflow-y-auto p-4 md:p-6 pb-28 md:pb-6">
      <div className="mx-auto w-full max-w-[1440px]">{children}</div>
    </main>
  );
}
