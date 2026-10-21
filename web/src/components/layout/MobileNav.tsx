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
import { COMMUNITY_LAUNCH_ENABLED } from '@/lib/launch-features';
import {
  CommunityIcon,
  CreateIcon,
  DiscoverIcon,
  FocusIcon,
  NAV_ACCENT,
  type NavIconProps,
} from './NavIcons';

// Mirrors iOS LivingHubTabBar (MainTabView.swift): two icon groups flanking
// the center mascot FAB — Focus, Discover · Community, Create. Icon-only
// ghost tabs with a dot indicator, mascot floats in the middle with a
// breathing glow.
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
// The glyphs are the set drawn in `NavIcons`, the same ones the desktop rail
// carries. This bar ran on stock Lucide — the target, compass and two-person
// group every other app ships — so a learner who met the drawn set on desktop
// met a different nav on their phone. Half the complaint about the old icons
// was the phone's.
const focusItem = { href: NAV.focus.href, icon: FocusIcon, label: NAV.focus.label };
const discoverItem = { href: NAV.discover.href, icon: DiscoverIcon, label: NAV.discover.label };
const communityItem = { href: NAV.community.href, icon: CommunityIcon, label: NAV.community.label };

const leftItems = COMMUNITY_LAUNCH_ENABLED ? [focusItem, discoverItem] : [focusItem];

const rightItems = COMMUNITY_LAUNCH_ENABLED ? [communityItem] : [discoverItem];

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
      className="flex flex-col items-center justify-center gap-1 px-4 py-2 transition-all duration-200"
    >
      <Icon
        className={cn(
          'w-6 h-6 text-white transition-all duration-200',
          isActive
            ? 'opacity-100 scale-110 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]'
            : 'opacity-50',
        )}
        accent={isActive ? NAV_ACCENT : undefined}
      />
      <span
        className={cn(
          'w-1 h-1 rounded-full bg-white transition-opacity duration-200',
          isActive ? 'opacity-100' : 'opacity-0',
        )}
      />
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
      <div className="flex items-center justify-between h-20 px-6">
        <div className="flex items-center gap-2">
          {leftItems.map((item) => (
            <GhostTab key={item.href} {...item} isActive={isItemActive(item.href)} />
          ))}
        </div>

        {/* Center mascot FAB — floats above the bar in a glow, breathing.
            Lyo "lives" here when not in chat and flies to the chat header
            on tap (shared layoutId). */}
        <Link
          href="/chat"
          aria-label={`${NAV.askLyo.label} chat`}
          aria-current={isChat ? 'page' : undefined}
          className="relative flex items-center justify-center -mt-10"
        >
          <span className="absolute w-28 h-28 rounded-full mascot-fab-glow pointer-events-none" />
          <div
            className={cn(
              'relative w-[70px] h-[70px] rounded-full flex items-center justify-center',
              'animate-breathe transition-transform duration-200 active:scale-95',
              'drop-shadow-[0_5px_10px_rgba(167,139,250,0.6)]',
            )}
          >
            {!isChat && (
              <motion.div
                layoutId={LYO_MASCOT_LAYOUT_ID}
                transition={{ layout: { type: 'spring', bounce: 0.35, duration: 0.6 } }}
                className="flex items-center justify-center"
              >
                <MascotAvatar idle size={64} />
              </motion.div>
            )}
          </div>
        </Link>

        <div className="flex items-center gap-2">
          {rightItems.map((item) => (
            <GhostTab key={item.href} {...item} isActive={isItemActive(item.href)} />
          ))}

          {/* Create — opens the creation sheet, mirroring the iOS plus tab */}
          <button
            onClick={() => setCreateOpen(true)}
            aria-label={NAV.create.label}
            className="flex flex-col items-center justify-center gap-1 px-4 py-2 transition-all duration-200"
          >
            <CreateIcon
              className={cn(
                'w-6 h-6 text-white transition-all duration-200',
                createOpen
                  ? 'opacity-100 scale-110 drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]'
                  : 'opacity-50'
              )}
              accent={createOpen ? NAV_ACCENT : undefined}
            />
            <span
              className={cn(
                'w-1 h-1 rounded-full bg-white transition-opacity duration-200',
                createOpen ? 'opacity-100' : 'opacity-0'
              )}
            />
          </button>
        </div>
      </div>

      <CreateSheet isOpen={createOpen} onClose={() => setCreateOpen(false)} />
    </nav>
  );
}

export default MobileNav;
