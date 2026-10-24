'use client';

import React, { useEffect, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Settings } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

import { cn } from '@/lib/utils';
import { useAuthStore } from '@/stores/auth-store';
import { COMMUNITY_LAUNCH_ENABLED, DISCOVER_LAUNCH_ENABLED } from '@/lib/launch-features';
import CreateSheet from '@/components/create/CreateSheet';
import {
  NAV,
  SIDEBAR_ITEMS,
  isActiveHref,
  isRailShortcut,
  readCollapsed,
  safeStorage,
  writeCollapsed,
} from '@/lib/nav-items.mjs';
import { NAV_ACCENT, NAV_ICONS, RailToggleIcon } from './NavIcons';

/**
 * The desktop rail.
 *
 * Three things were wrong with it. It set the wordmark in a gradient font
 * instead of using the logo, and shipped the internal name "DA ONE" to
 * learners. It ran on stock icons — the same house and speech bubble as every
 * other AI product. And it said "Home" and "LYO Tutor" when iOS, Android and
 * this site's own phone nav all say Focus, and reach the AI by tapping the
 * mascot.
 *
 * So: the real mark, the drawn set in `NavIcons`, the mascot carrying Ask Lyo
 * exactly as it does on the phone, and labels read from `nav-items.mjs` —
 * which the phone nav reads too, so the two cannot disagree again.
 *
 * The rail also already collapsed; it just forgot, reopening on every page
 * load, which is what made it feel broken. It remembers now.
 */

export function Sidebar() {
  const pathname = usePathname();
  const { user } = useAuthStore();
  const [collapsed, setCollapsed] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);

  // Read after mount, never during render: the server has no localStorage, and
  // seeding state from it directly would hydrate a closed rail into an open
  // one and warn about the mismatch.
  useEffect(() => {
    setCollapsed(readCollapsed(safeStorage(typeof window === 'undefined' ? null : window)));
  }, []);

  const toggle = () =>
    setCollapsed((was) => {
      const next = !was;
      writeCollapsed(safeStorage(typeof window === 'undefined' ? null : window), next);
      return next;
    });

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (isActiveHref('/classroom', pathname) || !isRailShortcut(event)) return;
      event.preventDefault();
      toggle();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // Keep the active lesson in its own focused layout. `MainContent` treats
  // the classroom as immersive and both `TopBar` and `MobileNav` hide
  // themselves there, so a 264px rail beside a lesson is exactly the chrome
  // the rest of the shell suppresses. After the hooks, never before: every
  // hook above still runs on every route, so this only skips the markup.
  if (isActiveHref('/classroom', pathname)) return null;

  const open = !collapsed;
  const profileActive = isActiveHref(NAV.profile.href, pathname);
  const settingsActive = isActiveHref(NAV.settings.href, pathname);

  return (
    <>
      <motion.aside
        animate={{ width: open ? 264 : 76 }}
        transition={{ type: 'spring', stiffness: 400, damping: 40 }}
        className={cn(
          'hidden md:flex flex-col h-screen bg-[#0d0f18]/60 backdrop-blur-2xl',
          'border-r border-white/[0.06] overflow-hidden shrink-0 relative z-20',
        )}
      >
        {/* ---- Brand ---- */}
        {/* The mark stays at both widths. Hiding it on collapse left the rail
            with no brand on it at all — just a toggle floating at the top. */}
        <div
          className={cn(
            'flex shrink-0 px-3.5',
            open ? 'h-[76px] flex-row items-center gap-2.5' : 'flex-col items-center gap-2.5 py-4',
          )}
        >
          <Link href={NAV.focus.href} aria-label="Lyo — go to Focus" className="block shrink-0">
            {/* The declared size is the drawn size, not the file's 512x463:
                Next builds its srcset from these numbers, so naming the file's
                dimensions made every visit fetch a ~500px mark to paint 33 of
                them. 34x31 keeps the 512:463 ratio, and the 2x candidate Next
                adds on top stays crisp on a retina screen.

                No `priority` either. This rail is only CSS-hidden on a phone —
                it still mounts — so a priority preload here jumped the queue
                ahead of the actual page on the devices that never show it. */}
            <Image
              src="/brand/lyo-logo.png"
              alt="Lyo"
              width={34}
              height={31}
              className="h-[30px] w-auto object-contain"
            />
          </Link>

          {open && <span className="flex-1" />}

          <button
            type="button"
            onClick={toggle}
            aria-label={open ? 'Collapse the menu' : 'Expand the menu'}
            aria-expanded={open}
            title={open ? 'Collapse the menu  [' : 'Expand the menu  ['}
            className={cn(
              'flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px]',
              'bg-white/5 text-white/55 transition-colors hover:bg-white/10 hover:text-white',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#6366f1]/60',
            )}
          >
            <RailToggleIcon className="h-4 w-4" />
          </button>
        </div>

        {/* ---- Nav ---- */}
        <nav aria-label="Main" className="flex flex-1 flex-col gap-[3px] overflow-y-auto px-2.5 no-scrollbar">
          {SIDEBAR_ITEMS.filter(
            (item) =>
              (item.key !== 'community' || COMMUNITY_LAUNCH_ENABLED) &&
              (item.key !== 'discover' || DISCOVER_LAUNCH_ENABLED),
          ).map((item) => {
            const active = item.action === 'create' ? false : isActiveHref(item.href, pathname);
            const Icon = NAV_ICONS[item.key as keyof typeof NAV_ICONS];
            const isLyo = item.key === 'askLyo';

            const body = (
              <>
                {active && (
                  <span
                    aria-hidden
                    className="absolute -left-[6px] top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[#ff8c00]"
                  />
                )}

                {isLyo ? (
                  // The mascot is the icon. Tapping it is already how the
                  // phone reaches Lyo; this makes the desktop the same gesture.
                  <span className="relative flex h-[26px] w-[26px] shrink-0 items-center justify-center">
                    <span
                      aria-hidden
                      className="absolute -inset-[5px] rounded-full bg-[radial-gradient(circle,rgba(255,140,0,0.45)_0%,transparent_70%)]"
                    />
                    <Image
                      src="/mascot/mascot_standing.png"
                      alt=""
                      width={46}
                      height={46}
                      aria-hidden
                      className="relative h-[26px] w-[26px] object-contain animate-breathe"
                    />
                  </span>
                ) : (
                  Icon && (
                    <Icon
                      className="h-[21px] w-[21px] shrink-0"
                      accent={active ? NAV_ACCENT : undefined}
                    />
                  )
                )}

                <AnimatePresence initial={false}>
                  {open && (
                    <motion.span
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.12 }}
                      className="whitespace-nowrap text-sm"
                    >
                      {item.label}
                    </motion.span>
                  )}
                </AnimatePresence>

                {isLyo && open && (
                  <span className="ml-auto rounded-md bg-[#ff8c00]/[0.18] px-[7px] py-0.5 text-[9px] font-bold tracking-[0.08em] text-[#ffb766]">
                    AI
                  </span>
                )}
              </>
            );

            const shell = cn(
              'relative flex min-h-[44px] items-center gap-3 rounded-[14px] transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#6366f1]/60',
              open ? 'px-3' : 'justify-center px-0',
              active
                ? 'bg-white/[0.07] font-semibold text-white'
                : 'text-white/[0.62] hover:bg-white/5 hover:text-white',
            );

            // Create is the one item that is not a place: it opens the same
            // sheet the phone nav opens, so it has to be a button.
            if (item.action === 'create') {
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setCreateOpen(true)}
                  aria-label={item.label}
                  title={open ? undefined : item.label}
                  className={shell}
                >
                  {body}
                </button>
              );
            }

            return (
              <Link
                key={item.key}
                href={item.href}
                aria-label={item.label}
                aria-current={active ? 'page' : undefined}
                title={open ? undefined : item.label}
                className={shell}
              >
                {body}
              </Link>
            );
          })}
        </nav>

        {/* ---- The learner ---- */}
        {/* Two destinations, so two links. The cog used to sit inside the
            profile link, which meant clicking it opened /profile — the one
            place a settings button should never go. */}
        <div
          className={cn(
            'flex shrink-0 items-center gap-1 border-t border-white/[0.07] p-2.5',
            open ? 'flex-row' : 'flex-col',
          )}
        >
          <Link
            href={NAV.profile.href}
            aria-label={NAV.profile.label}
            aria-current={profileActive ? 'page' : undefined}
            title={open ? undefined : NAV.profile.label}
            className={cn(
              'relative flex min-h-[44px] items-center gap-3 rounded-[14px] transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#6366f1]/60',
              open ? 'min-w-0 flex-1 px-3' : 'w-full justify-center px-0',
              profileActive
                ? 'bg-white/[0.07] text-white'
                : 'text-white/[0.62] hover:bg-white/5 hover:text-white',
            )}
          >
            {profileActive && (
              <span
                aria-hidden
                className="absolute -left-[6px] top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[#ff8c00]"
              />
            )}

            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#6366f1] to-[#8b5cf6] text-[11px] font-bold text-white">
              {(user?.displayName ?? 'You').slice(0, 2).toUpperCase()}
            </span>

            <AnimatePresence initial={false}>
              {open && (
                <motion.span
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.12 }}
                  className="min-w-0 flex-1 overflow-hidden"
                >
                  <span className="block truncate text-xs font-semibold text-white">
                    {user?.displayName ?? 'You'}
                  </span>
                  <span className="block truncate text-[10px] text-white/50">
                    Level {user?.level ?? 1} · {(user?.xp ?? 0).toLocaleString()} XP
                  </span>
                </motion.span>
              )}
            </AnimatePresence>
          </Link>

          {/* Shown collapsed too, stacked under the avatar. The old rail
              dropped it on collapse, which put the only route to Settings
              behind reopening the menu first. */}
          <Link
            href={NAV.settings.href}
            aria-label={NAV.settings.label}
            aria-current={settingsActive ? 'page' : undefined}
            title={NAV.settings.label}
            className={cn(
              'flex h-9 w-9 shrink-0 items-center justify-center rounded-[11px] transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#6366f1]/60',
              settingsActive
                ? 'bg-white/[0.07] text-white'
                : 'text-white/40 hover:bg-white/5 hover:text-white',
            )}
          >
            <Settings className="h-4 w-4" aria-hidden />
          </Link>
        </div>

      </motion.aside>

      <CreateSheet isOpen={createOpen} onClose={() => setCreateOpen(false)} />
    </>
  );
}
