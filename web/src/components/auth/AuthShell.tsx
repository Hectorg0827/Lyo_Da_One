'use client';

import { useId } from 'react';
import { motion } from 'framer-motion';

/** The backdrop, card and heading the sign-in pages share. */
export function AuthShell({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className="flex min-h-screen items-center justify-center p-4"
      style={{
        background: 'radial-gradient(ellipse 80% 80% at 50% -20%, rgba(99,102,241,0.25) 0%, rgba(10,10,15,1) 60%)',
      }}
    >
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
        className="relative z-10 w-full max-w-md"
      >
        <div
          className="space-y-6 rounded-3xl p-8"
          style={{
            background: 'rgba(17,17,24,0.85)',
            backdropFilter: 'blur(24px)',
            border: '1px solid rgba(255,255,255,0.08)',
            boxShadow: '0 32px 80px rgba(0,0,0,0.5)',
          }}
        >
          <div className="text-center">
            <h1 className="text-2xl font-black text-primary">{title}</h1>
            <p className="mt-1 text-sm text-secondary">{subtitle}</p>
          </div>
          {children}
        </div>
      </motion.div>
    </div>
  );
}

/** A labelled input styled like the login form's. */
export function AuthField({
  label,
  type,
  value,
  onChange,
  autoComplete,
  icon: Icon,
}: {
  label: string;
  type: string;
  value: string;
  onChange: (value: string) => void;
  autoComplete: string;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
}) {
  const id = useId();
  return (
    <div className="space-y-1.5">
      <label htmlFor={id} className="text-xs font-semibold uppercase tracking-wider text-secondary">
        {label}
      </label>
      <div
        className="flex items-center gap-3 rounded-xl px-4 py-3 focus-within:ring-1 focus-within:ring-[#6366f1]/60"
        style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)' }}
      >
        <Icon size={16} className="shrink-0 text-secondary" />
        <input
          id={id}
          type={type}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          autoComplete={autoComplete}
          required
          className="min-w-0 flex-1 bg-transparent text-sm text-primary outline-none placeholder:text-secondary"
        />
      </div>
    </div>
  );
}

export const authButtonClass =
  'w-full rounded-xl py-3.5 text-sm font-bold text-white transition-all duration-200 hover:opacity-90 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-60';
export const authButtonStyle = { background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)' };
export const authLinkClass = 'font-semibold text-[#a78bfa] transition-colors duration-150 hover:text-[#6366f1]';
