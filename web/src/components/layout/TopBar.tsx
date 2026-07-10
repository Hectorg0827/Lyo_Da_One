'use client';

import React, { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Bell, MessageSquare, Search, User, Settings, LogOut } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Avatar } from '@/components/ui/Avatar';
import { useAuthStore } from '@/stores/auth-store';

export function TopBar() {
  const router = useRouter();
  const { user, logout } = useAuthStore();

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
    router.push('/login');
  }

  return (
    <header
      className={cn(
        'sticky top-0 z-30 h-16 flex items-center gap-4 px-4 md:px-6',
        'bg-black/60 backdrop-blur-md border-b border-white/5',
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
              'focus:outline-none focus:ring-2 focus:ring-[#6c63ff]/60 focus:border-[#6c63ff]',
              'transition-all duration-200',
            )}
            aria-label="Search courses, clips, and topics"
          />
        </div>
      </div>

      {/* Right: Action buttons */}
      <div className="flex items-center gap-1 shrink-0">
        {/* Notifications */}
        <Link
          href="/notifications"
          className="relative p-2 rounded-xl text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-white/5 transition-colors"
          aria-label="Notifications"
        >
          <Bell className="w-5 h-5" />
          {/* Red dot indicator */}
          <span
            className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-red-500"
            aria-hidden="true"
          />
        </Link>

        {/* Messages */}
        <Link
          href="/messages"
          className="relative p-2 rounded-xl text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-white/5 transition-colors"
          aria-label="Messages"
        >
          <MessageSquare className="w-5 h-5" />
          {/* Count badge */}
          <span
            className="absolute top-1 right-1 min-w-[16px] h-4 px-1 flex items-center justify-center rounded-full bg-[#6c63ff] text-white text-[9px] font-bold leading-none"
            aria-hidden="true"
          >
            2
          </span>
        </Link>

        {/* User avatar + dropdown */}
        <div className="relative ml-1" ref={dropdownRef}>
          <button
            onClick={() => setDropdownOpen((o) => !o)}
            className="rounded-full ring-2 ring-transparent hover:ring-[#6c63ff]/50 transition-all focus-visible:outline-none focus-visible:ring-[#6c63ff]/60"
            aria-label="Open profile menu"
            aria-expanded={dropdownOpen}
            aria-haspopup="menu"
          >
            <Avatar
              name={user?.displayName ?? 'User'}
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
                'bg-[var(--surface)] border border-white/10',
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
    </header>
  );
}

export default TopBar;
