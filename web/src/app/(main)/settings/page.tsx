'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { AtSign, ExternalLink, Info, Mail, Save, User } from 'lucide-react';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-2xl border border-white/[0.08] bg-white/[0.035]">
      <div className="border-b border-white/[0.06] px-5 py-4">
        <h2 className="text-sm font-bold text-primary">{title}</h2>
      </div>
      {children}
    </section>
  );
}

function ReadOnlyRow({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof User;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-3 border-b border-white/[0.04] px-5 py-4 last:border-b-0">
      <Icon size={16} className="shrink-0 text-secondary" />
      <div className="min-w-0 flex-1">
        <p className="text-xs font-semibold uppercase tracking-wide text-secondary">{label}</p>
        <p className="mt-1 truncate text-sm text-primary">{value || 'Not set'}</p>
      </div>
      <span className="text-[10px] font-semibold uppercase tracking-wide text-white/30">Account</span>
    </div>
  );
}

function ExternalRow({
  label,
  href,
}: {
  label: string;
  href: string;
}) {
  return (
    <a
      href={href}
      target={href.startsWith('http') ? '_blank' : undefined}
      rel={href.startsWith('http') ? 'noreferrer' : undefined}
      className="flex items-center justify-between border-b border-white/[0.04] px-5 py-4 text-sm text-primary transition-colors hover:bg-white/[0.04] last:border-b-0"
    >
      <span>{label}</span>
      <ExternalLink size={14} className="text-secondary" />
    </a>
  );
}

export default function SettingsPage() {
  const { user, updateUser } = useAuthStore();
  const [displayName, setDisplayName] = useState(user?.displayName ?? '');
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<'idle' | 'saved' | 'error'>('idle');

  useEffect(() => {
    setDisplayName(user?.displayName ?? '');
  }, [user?.displayName]);

  async function saveDisplayName() {
    const value = displayName.trim();
    if (!value || value === user?.displayName || saving) return;

    setSaving(true);
    setStatus('idle');
    try {
      await api.auth.updateProfile({ full_name: value });
      updateUser({ displayName: value });
      setStatus('saved');
    } catch {
      setStatus('error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      className="mx-auto max-w-2xl space-y-5 px-4 py-6 sm:px-6"
    >
      <header>
        <h1 className="font-rounded text-2xl font-black text-primary">Settings</h1>
        <p className="mt-1 text-sm text-secondary">
          Only settings that are actually connected to your Lyo account are shown here.
        </p>
      </header>

      <Section title="Account">
        <div className="border-b border-white/[0.04] px-5 py-4">
          <label htmlFor="display-name" className="text-xs font-semibold uppercase tracking-wide text-secondary">
            Display name
          </label>
          <div className="mt-2 flex gap-2">
            <div className="flex min-w-0 flex-1 items-center gap-3 rounded-xl border border-white/10 bg-white/[0.04] px-3">
              <User size={16} className="shrink-0 text-secondary" />
              <input
                id="display-name"
                value={displayName}
                onChange={(event) => {
                  setDisplayName(event.target.value);
                  setStatus('idle');
                }}
                className="min-w-0 flex-1 bg-transparent py-3 text-sm text-primary outline-none"
                autoComplete="name"
              />
            </div>
            <button
              type="button"
              onClick={() => void saveDisplayName()}
              disabled={saving || !displayName.trim() || displayName.trim() === user?.displayName}
              className="flex min-w-[92px] items-center justify-center gap-2 rounded-xl bg-lyo-600 px-4 text-sm font-semibold text-white transition hover:bg-lyo-500 disabled:cursor-not-allowed disabled:opacity-40"
            >
              <Save size={14} />
              {saving ? 'Saving…' : 'Save'}
            </button>
          </div>
          {status === 'saved' && <p className="mt-2 text-xs text-emerald-400">Saved to your Lyo account.</p>}
          {status === 'error' && <p className="mt-2 text-xs text-red-400">Could not save. Your previous account value is unchanged.</p>}
        </div>

        <ReadOnlyRow icon={Mail} label="Email" value={user?.email ?? ''} />
        <ReadOnlyRow icon={AtSign} label="Username" value={user?.username ? `@${user.username}` : ''} />
      </Section>

      <Section title="About & support">
        <ExternalRow label="Terms of Service" href="https://lyo.app/terms" />
        <ExternalRow label="Privacy Policy" href="https://lyo.app/privacy" />
        <ExternalRow label="Contact Support" href="mailto:support@lyo.app" />
      </Section>

      <section className="rounded-2xl border border-amber-400/20 bg-amber-400/[0.05] px-5 py-4">
        <div className="flex items-start gap-3">
          <Info size={17} className="mt-0.5 shrink-0 text-amber-300" />
          <div>
            <h2 className="text-sm font-semibold text-amber-100">Account deletion</h2>
            <p className="mt-1 text-sm leading-relaxed text-white/55">
              Lyo does not currently expose a verified account-deletion endpoint on the web. The old button only signed users out, so it has been removed.
            </p>
            <a href="mailto:support@lyo.app?subject=Account%20deletion%20request" className="mt-2 inline-flex text-sm font-semibold text-amber-200 hover:text-amber-100">
              Request account deletion
            </a>
          </div>
        </div>
      </section>
    </motion.div>
  );
}
