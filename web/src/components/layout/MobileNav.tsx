'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';
import MascotAvatar from '@/components/chat/MascotAvatar';
import CreateSheet from '@/components/create/CreateSheet';
import { LYO_MASCOT_LAYOUT_ID } from '@/lib/motion-ids';
import { NAV, isActiveHref } from '@/lib/nav-items.mjs';
import { COMMUNITY_LAUNCH_ENABLED, DISCOVER_LAUNCH_ENABLED, PREVIEW_SHOW_GATED_DISCOVER_TAB } from '@/lib/launch-features';
import {
  CommunityIcon,
  CreateIcon,
  DiscoverIcon,
  FocusIcon,
  NAV_ACCENT,
  type NavIconProps,
} from './NavIcons';

// Mirrors the five iOS LivingHubTabBar destinations: Focus, Discover,
// Ask Lyo, Community, Create. The five equal-width mobile slots and compact
// in-bar mascot keep each tap target balanced on narrow phone screens.
//
// The labels come from `nav-items.mjs`, the same file the desktop rail reads.
// They used to be written out here and in the sidebar separately, which is
// how the two navs on this one site ended up calling the home screen
// different things.
//
// While Community is held back from launch its slot on the right would sit
// empty, leaving Focus and Discover crowded together on one side of the
// mascot. Discover moves into that slot instead, and Focus keeps the left on
// its own. When the flag turns on, Community takes its slot back and Discover
// returns to the left, which is the arrangement iOS and Android ship.
//
// Discover has its own launch flag. The isolated preview may show its entry
// even while disabled: tapping it opens the existing safe update notice,
// never the clip feed, and production keeps the normal containment.
//
// The glyphs are the set drawn in `NavIcons`, the same ones the desktop rail
// carries. This bar ran on stock Lucide — the target, compass and two-person
// group every other app ships — so a learner who met the drawn set on desktop
// met a different nav on their phone. Half the complaint about the old icons
// was the phone's.
const focusItem = { href: NAV.focus.href, icon: FocusIcon, label: NAV.focus.label };
const discoverItem = { href: NAV.discover.href, icon: DiscoverIcon, label: NAV.discover.label };
const communityItem = { href: NAV.community.href, icon: CommunityIcon, label: NAV.community.label };

const discoverItems = (DISCOVER_LAUNCH_ENABLED || PREVIEW_SHOW_GATED_DISCOVER_TAB) ? [discoverItem] : [];

const leftItems = COMMUNITY_LAUNCH_ENABLED ? [focusItem, ...discoverItems] : [focusItem];

const rightItems = COMMUNITY_LAUNCH_ENABLED ? [communityItem] : discoverItems;

function GhostTab({
  href,
  icon: Icon,
  label,
  isActive,
}: {
  href: string;
  icon: React.ComponentType<NavIconProps>;
  label: string;
  isActive: boolean;
}) {
  return (
    <Link
      key={href}
      href={href}
      aria-label={label}
      aria-current={isActive ? 'page' : undefined}
      className="flex w-full min-w-0 min-h-[58px] flex-col items-center justify-center gap-1 py-2 transition-colors duration-200 touch-manipulation"
    >
      <Icon
        className={cn(
          'w-6 h-6 text-white transition-all duration-200',
          isActive
            ? 'opacity-100 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]'
            : 'opacity-70',
        )}
        accent={isActive ? NAV_ACCENT : undefined}
      />
      <span
        className={cn(
          'max-w-full whitespace-nowrap text-[10px] leading-3 font-medium tracking-tight',
          isActive ? 'text-white' : 'text-white/65',
        )}
      >
        {label}
      </span>
    </Link>
  );
}

export function MobileNav() {
  const pathname = usePathname();
  const isChat = pathname.startsWith('/chat');
  const [createOpen, setCreateOpen] = useState(false);

  const isItemActive = (href: string) => isActiveHref(href, pathname);

  // The classroom has its own teacher presence and exit control. Keeping the
  // global mascot FAB here duplicates Lyo and occupies the answer area.
  if (isActiveHref('/classroom', pathname)) {
    return null;
  }

  return (
    <nav
      className={cn(
        'md:hidden fixed bottom-0 left-0 right-0 z-50',
        'bg-[#0d0f18]/75 backdrop-blur-2xl',
        'border-t border-white/10',
        'pb-[env(safe-area-inset-bottom)]',
      )}
      aria-label="Mobile navigation"
    >
      <div className="grid h-[68px] grid-cols-5 items-center px-1">
        {/* Display: contents keeps the DOM groups for navigation tests while
            giving each action its own equal-width column on small phones. */}
        <div className="contents">
          {leftItems.map((item) => (
            <GhostTab key={item.href} {...item} isActive={isItemActive(item.href)} />
          ))}
          {leftItems.length < 2 && <span aria-hidden="true" />}
        </div>

        {/* Lyo stays the recognizable center action without covering the feed.
            No oversized float, and the touch target remains at least 60px. */}
        <Link
          href="/chat"
          aria-label={`${NAV.askLyo.label} chat`}
          aria-current={isChat ? 'page' : undefined}
          className="relative flex w-full min-w-0 min-h-[60px] flex-col items-center justify-center gap-0.5 touch-manipulation"
        >
          <span className="pointer-events-none absolute left-1/2 top-1 h-10 w-10 -translate-x-1/2 rounded-full mascot-fab-glow opacity-30" />
          <div className="relative flex h-9 w-9 items-center justify-center transition-transform duration-200 active:scale-95">
            {!isChat ? (
              <motion.div
                layoutId={LYO_MASCOT_LAYOUT_ID}
                transition={{ layout: { type: 'spring', bounce: 0.35, duration: 0.6 } }}
                className="flex items-center justify-center"
              >
                <MascotAvatar size={34} />
              </motion.div>
            ) : (
              <MascotAvatar size={34} />
            )}
          </div>
          <span className={cn(
            'relative whitespace-nowrap text-[10px] leading-3 font-semibold tracking-tight',
            isChat ? 'text-white' : 'text-white/70',
          )}>Ask Lyo</span>
        </Link>

        <div className="contents">
          {rightItems.length === 0 && <span aria-hidden="true" />}
          {rightItems.map((item) => (
            <GhostTab key={item.href} {...item} isActive={isItemActive(item.href)} />
          ))}

          {/* Create opens the existing creation sheet. */}
          <button
            onClick={() => setCreateOpen(true)}
            aria-label={NAV.create.label}
            className="flex w-full min-w-0 min-h-[58px] flex-col items-center justify-center gap-1 py-2 transition-colors duration-200 touch-manipulation"
          >
            <CreateIcon
              className={cn(
                'w-6 h-6 text-white transition-all duration-200',
                createOpen
                  ? 'opacity-100 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]'
                  : 'opacity-70',
              )}
              accent={createOpen ? NAV_ACCENT : undefined}
            />
            <span className={cn(
              'whitespace-nowrap text-[10px] leading-3 font-medium tracking-tight',
              createOpen ? 'text-white' : 'text-white/65',
            )}>Create</span>
          </button>
        </div>
      </div>

      <CreateSheet isOpen={createOpen} onClose={() => setCreateOpen(false)} />
    </nav>
  );
}

export default MobileNav;
