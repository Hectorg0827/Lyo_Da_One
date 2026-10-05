'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { AtSign, Check, Info, Mail, Pencil, User, X } from 'lucide-react';
import { api } from '@/lib/api';
import { useAuthStore } from '@/stores/auth-store';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: { opacity: 1, transition: { staggerChildren: 0.06 } },
};

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.35, ease: [0.22, 1, 0.36, 1] as [number, number, number, number] },
  },
};

function SectionCard({
  title,
  icon: Icon,
  children,
}: {
  title: string;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
  children: React.ReactNode;
}) {
  return (
    <motion.section variants={itemVariants} className="glass-card overflow-hidden">
      <div className="flex items-center gap-3 border-b border-white/[0.06] px-5 py-4">
        <div className="grid h-8 w-8 place-items-center rounded-lg bg-white/[0.06]">
          <Icon size={16} className="text-lyo-300" />
        </div>
        <h2 className="text-sm font-bold text-primary">{title}</h2>
      </div>
      <div className="divide-y divide-white/[0.05]">{children}</div>
    </motion.section>
  );
}

function ReadOnlyRow({
  label,
  value,
  icon: Icon,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ size?: number | string; className?: string }>;
}) {
  return (
    <div className="flex items-center gap-3 px-5 py-4">
      <Icon size={15} className="shrink-0 text-secondary" />
      <div className="min-w-0">
        <p className="text-xs font-semibold uppercase tracking-wide text-secondary">{label}</p>
        <p className="mt-0.5 truncate text-sm text-primary">{value || 'Not set'}</p>
      </div>
    </div>
  );
}

export default function SettingsPage() {
  const { user, updateUser } = useAuthStore();
  const [displayName, setDisplayName] = useState(user?.displayName ?? '');
  const [draft, setDraft] = useState(user?.displayName ?? '');
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const next = user?.displayName ?? '';
    setDisplayName(next);
    if (!editing) setDraft(next);
  }, [user?.displayName, editing]);

  const saveDisplayName = async () => {
    const next = draft.trim();
    if (!next || next === displayName || saving) {
      setEditing(false);
      setDraft(displayName);
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const updated = await api.auth.updateProfile({ full_name: next });
      setDisplayName(updated.displayName);
      setDraft(updated.displayName);
      updateUser({ displayName: updated.displayName });
      setEditing(false);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Your profile could not be updated.');
    } finally {
      setSaving(false);
    }
  };

  if (!user) return null;

  return (
    <motion.div
      variants={containerVariants}
      initial="hidden"
      animate="visible"
      className="mx-auto max-w-2xl space-y-5 px-4 py-6 sm:px-6"
    >
      <motion.header variants={itemVariants}>
        <h1 className="font-rounded text-xl font-black text-primary">Settings</h1>
        <p className="mt-0.5 text-sm text-secondary">
          Only settings that are actually stored by your LYO account are shown here.
        </p>
      </motion.header>

      <SectionCard title="Account" icon={User}>
        <div className="px-5 py-4">
          <div className="mb-2 flex items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <User size={15} className="text-secondary" />
              <div>
                <p className="text-xs font-semibold uppercase tracking-wide text-secondary">Display name</p>
                {!editing && <p className="mt-0.5 text-sm text-primary">{displayName || 'Not set'}</p>}
              </div>
            </div>
            {!editing && (
              <button
                type="button"
                onClick={() => { setDraft(displayName); setEditing(true); setError(null); }}
                className="flex min-h-9 items-center gap-1.5 rounded-lg px-3 text-xs font-semibold text-lyo-300 hover:bg-white/[0.05]"
              >
                <Pencil size={13} /> Edit
              </button>
            )}
          </div>

          {editing && (
            <div className="flex gap-2">
              <input
                autoFocus
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') void saveDisplayName();
                  if (event.key === 'Escape') { setEditing(false); setDraft(displayName); setError(null); }
                }}
                className="min-w-0 flex-1 rounded-xl border border-white/10 bg-white/[0.04] px-3 py-2.5 text-sm text-primary outline-none focus:border-lyo-500"
                aria-label="Display name"
              />
              <button
                type="button"
                onClick={() => void saveDisplayName()}
                disabled={saving || !draft.trim()}
                className="grid min-h-10 min-w-10 place-items-center rounded-xl bg-lyo-600 text-white disabled:opacity-40"
                aria-label="Save display name"
              >
                <Check size={16} />
              </button>
              <button
                type="button"
                onClick={() => { setEditing(false); setDraft(displayName); setError(null); }}
                className="grid min-h-10 min-w-10 place-items-center rounded-xl border border-white/10 text-secondary hover:bg-white/[0.05] hover:text-primary"
                aria-label="Cancel editing"
              >
                <X size={16} />
              </button>
            </div>
          )}
          {error && <p role="alert" className="mt-2 text-sm text-red-400">{error}</p>}
        </div>

        <ReadOnlyRow label="Email" value={user.email ?? ''} icon={Mail} />
        <ReadOnlyRow label="Username" value={user.username ? `@${user.username}` : ''} icon={AtSign} />
      </SectionCard>

      <SectionCard title="About" icon={Info}>
        <div className="flex items-center justify-between px-5 py-4">
          <div>
            <p className="text-sm font-medium text-primary">LYO Web</p>
            <p className="mt-0.5 text-xs text-secondary">Account settings are intentionally limited to capabilities backed by the live API.</p>
          </div>
          <span className="text-xs text-secondary">1.0.0 beta</span>
        </div>
      </SectionCard>
    </motion.div>
  );
}
