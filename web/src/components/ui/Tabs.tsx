'use client';

import React, { ReactNode } from 'react';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

interface Tab {
  id: string;
  label: string;
  icon?: ReactNode;
}

interface TabsProps {
  tabs: Tab[];
  activeTab: string;
  onChange: (id: string) => void;
  className?: string;
}

export function Tabs({ tabs, activeTab, onChange, className }: TabsProps) {
  return (
    <div
      className={cn(
        'flex overflow-x-auto no-scrollbar border-b border-[var(--border)]',
        className,
      )}
      role="tablist"
      aria-label="Tabs"
    >
      {tabs.map((tab) => {
        const isActive = tab.id === activeTab;

        return (
          <button
            key={tab.id}
            role="tab"
            aria-selected={isActive}
            aria-controls={`panel-${tab.id}`}
            id={`tab-${tab.id}`}
            onClick={() => onChange(tab.id)}
            className={cn(
              'relative flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap',
              'transition-colors duration-200 shrink-0',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#6c63ff]/60 focus-visible:ring-inset',
              isActive
                ? 'text-[var(--text-primary)]'
                : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]',
            )}
          >
            {tab.icon && (
              <span className={cn('w-4 h-4', isActive ? 'text-[#6c63ff]' : 'text-current')}>
                {tab.icon}
              </span>
            )}
            {tab.label}

            {/* Animated underline indicator */}
            {isActive && (
              <motion.span
                layoutId="tab-indicator"
                className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-[#6c63ff] to-[#8b5cf6] rounded-full"
                transition={{ type: 'spring', stiffness: 500, damping: 40 }}
              />
            )}
          </button>
        );
      })}
    </div>
  );
}

export default Tabs;
