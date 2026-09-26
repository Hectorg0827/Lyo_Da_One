'use client';

import React, { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { useRouter, usePathname } from 'next/navigation';
import { Bell, MessageSquare, Search, User, Settings, LogOut } from 'lucide-react';
import { cn } from '@/lib/utils';
import { api } from '@/lib/api';
import { Avatar } from '@/components/ui/Avatar';
import { useAuthStore } from '@/stores/auth-store';
import { authSwitchHref } from '@/lib/auth-return.mjs';
import { UNREAD_CHANGED_EVENT, totalUnread, unreadBadge, unreadLabel } from '@/lib/unread.mjs';

const UNREAD_REFRESH_MS = 60_000;

/**
 * Real unread counts for the signed-in account, from the server. A failed
 * check keeps the last known counts rather than inventing any. Checked when
 * the app opens, on returning to the tab, every minute while it is visible,
 * on leaving the inbox pages, and when a page reports that it marked
 * something read (so reading clears the badge), not on every navigation.
 */
function useUnreadCounts(enabled: boolean, pathname: string) {
  const inboxKey =
    pathname.startsWith('/messages') || pathname.startsWith('/notifications') ? pathname : 'elsewhere';
  const [counts, setCounts] = useState({ notifications: 0, messages: 0 });

  useEffect(() => {
    if (!enabled) {
      setCounts({ notifications: 0, messages: 0 });
      return;
    }
    let cancelled = false;
    const refresh = async () => {
      const [notifications, messages] = await Promise.allSettled([
        api.notifications.unreadCount(),
        api.messages.unreadConversations(),
      ]);
      if (cancelled) return;
      setCounts((current) => ({
        notifications:
          notifications.status === 'fulfilled' ? Number(notifications.value?.count) || 0 : current.notifications,
        messages: messages.status === 'fulfilled' ? totalUnread(messages.value?.conversations) : current.messages,
      }));
    };
    void refresh();
    const timer = setInterval(() => {
      if (document.visibilityState === 'visible') void refresh();
    }, UNREAD_REFRESH_MS);
    const onFocus = () => void refresh();
    window.addEventListener('focus', onFocus);
    window.addEventListener(UNREAD_CHANGED_EVENT, onFocus);
    return () => {
      cancelled = true;
      clearInterval(timer);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener(UNREAD_CHANGED_EVENT, onFocus);
    };
  }, [enabled, inboxKey]);

  return counts;
}

export function TopBar() {
  const router = useRouter();
  const pathname = usePathname();
  const { user, isAuthenticated, isLoading, logout } = useAuthStore();
  const unread = useUnreadCounts(isAuthenticated, pathname);
  const notificationBadge = unreadBadge(unread.notifications);
  const messageBadge = unreadBadge(unread.messages);

  const [searchValue, setSearchValue] = useState('');
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    }
    if (dropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [dropdownOpen]);

  function handleLogout() {
    setDropdownOpen(false);
    logout();
    router.push('/auth/login');
  }

  // Focused classroom layout: no global search/notifications/messages
  // competing with an active lesson. All hooks above still run every
  // render — this only skips the header markup.
  if (pathname.startsWith('/classroom')) {
    return null;
  }

  const iconLinkClass =
    'relative p-2 rounded-xl text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-white/5 transition-colors';

  return (
    <header
      className={cn(
        'sticky top-0 z-30 h-16 flex items-center gap-4 px-4 md:px-6',
        'bg-[#0d0f18]/60 backdrop-blur-2xl border-b border-white/[0.06]',
        'shrink-0',
      )}
    >
      {/* Left: page title placeholder (desktop) */}
      <div className="hidden md:block w-40 shrink-0">
        <span className="text-sm font-medium text-[var(--text-secondary)]" aria-hidden="true" />
      </div>

      {/* Center: Search */}
      <div className="flex-1 max-w-xl mx-auto">
        <div className="relative">
          <Search
            className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--text-secondary)] pointer-events-none"
            aria-hidden="true"
          />
          <input
            type="search"
            value={searchValue}
            onChange={(e) => setSearchValue(e.target.value)}
            placeholder="Search courses, clips, topics..."
            className={cn(
              'w-full pl-9 pr-4 py-2 text-sm rounded-xl',
              'bg-[var(--surface-2)] border border-[var(--border)]',
              'text-[var(--text-primary)] placeholder:text-[var(--text-secondary)]',
              'focus:outline-none focus:ring-2 focus:ring-[#6366f1]/60 focus:border-[#6366f1]',
              'transition-all duration-200',
            )}
            aria-label="Search courses, clips, and topics"
          />
        </div>
      </div>

      {/* Right: account actions. Signed out, there is nothing personal to show. */}
      {isLoading ? (
        <div className="h-10 w-24 shrink-0" aria-hidden="true" />
      ) : !isAuthenticated ? (
        <Link
          href={authSwitchHref('/auth/login', `?next=${encodeURIComponent(pathname)}`)}
          className="shrink-0 rounded-xl bg-[#6366f1] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[#818cf8]"
        >
          Sign in
        </Link>
      ) : (
        <div className="flex items-center gap-1 shrink-0">
          {/* Notifications: a dot only when something is actually unread */}
          <Link href="/notifications" className={iconLinkClass} aria-label={unreadLabel('Notifications', unread.notifications)}>
            <Bell className="w-5 h-5" />
            {notificationBadge && (
              <span
                className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-red-500"
                aria-hidden="true"
                data-testid="notifications-unread"
              />
            )}
          </Link>

          {/* Messages: the real number of unread messages */}
          <Link href="/messages" className={iconLinkClass} aria-label={unreadLabel('Messages', unread.messages)}>
            <MessageSquare className="w-5 h-5" />
            {messageBadge && (
              <span
                className="absolute top-1 right-1 min-w-[16px] h-4 px-1 flex items-center justify-center rounded-full bg-[#6366f1] text-white text-[9px] font-bold leading-none"
                aria-hidden="true"
                data-testid="messages-unread"
              >
                {messageBadge}
              </span>
            )}
          </Link>

          {/* User avatar + dropdown */}
          <div className="relative ml-1" ref={dropdownRef}>
            <button
              onClick={() => setDropdownOpen((o) => !o)}
              className="rounded-full ring-2 ring-transparent hover:ring-[#6366f1]/50 transition-all focus-visible:outline-none focus-visible:ring-[#6366f1]/60"
              aria-label="Open profile menu"
              aria-expanded={dropdownOpen}
              aria-haspopup="menu"
            >
              <Avatar
                name={user?.displayName || user?.username || 'You'}
                src={user?.avatar || undefined}
                size="md"
              />
            </button>

            {/* Dropdown menu */}
            {dropdownOpen && (
              <div
                role="menu"
                className={cn(
                  'absolute right-0 mt-2 w-48 py-1 rounded-xl',
                  'bg-[#0d0f18]/95 backdrop-blur-2xl border border-white/12',
                  'shadow-xl shadow-black/40',
                  'z-50',
                )}
              >
                {/* User info header */}
                {user && (
                  <div className="px-4 py-2 border-b border-white/5">
                    <p className="text-sm font-semibold text-[var(--text-primary)] truncate">
                      {user.displayName}
                    </p>
                    <p className="text-xs text-[var(--text-secondary)] truncate">{user.email}</p>
                  </div>
                )}

                <Link
                  href="/profile"
                  role="menuitem"
                  onClick={() => setDropdownOpen(false)}
                  className="flex items-center gap-2.5 px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-white/5 transition-colors"
                >
                  <User className="w-4 h-4 shrink-0" />
                  Profile
                </Link>

                <Link
                  href="/settings"
                  role="menuitem"
                  onClick={() => setDropdownOpen(false)}
                  className="flex items-center gap-2.5 px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-white/5 transition-colors"
                >
                  <Settings className="w-4 h-4 shrink-0" />
                  Settings
                </Link>

                <div className="border-t border-white/5 mt-1 pt-1">
                  <button
                    role="menuitem"
                    onClick={handleLogout}
                    className="w-full flex items-center gap-2.5 px-4 py-2.5 text-sm text-red-400 hover:text-red-300 hover:bg-red-500/10 transition-colors"
                  >
                    <LogOut className="w-4 h-4 shrink-0" />
                    Logout
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </header>
  );
}

export default TopBar;
