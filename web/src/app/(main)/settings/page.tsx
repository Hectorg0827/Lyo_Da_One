'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { AlertTriangle, AtSign, ChevronRight, ExternalLink, Mail, Save, ShieldCheck, Trash2, User } from 'lucide-react';
import BlockedAccounts from '@/components/settings/BlockedAccounts';
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
  const router = useRouter();
  const { user, updateUser, deleteAccount } = useAuthStore();
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState(user?.displayName ?? '');
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState<'idle' | 'saved' | 'error'>('idle');
  const [moderator, setModerator] = useState(false);

  useEffect(() => {
    setDisplayName(user?.displayName ?? '');
  }, [user?.displayName]);

  useEffect(() => {
    api.moderation.me().then((result) => setModerator(result.moderator)).catch(() => setModerator(false));
  }, []);

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

  async function confirmDeleteAccount() {
    if (deleting) return;
    setDeleting(true);
    setDeleteError(null);
    const result = await deleteAccount();
    if (result.ok) {
      router.replace('/auth/login');
      return;
    }
    // Still signed in: the account was not deleted.
    setDeleteError(result.message);
    setDeleting(false);
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

      <Section title="Blocked accounts">
        <BlockedAccounts />
      </Section>

      {moderator && (
        <Section title="Moderation">
          <Link
            href="/moderation"
            className="flex items-center gap-3 px-5 py-4 text-sm text-primary transition-colors hover:bg-white/[0.04]"
          >
            <ShieldCheck size={16} className="shrink-0 text-secondary" />
            <span className="flex-1">Review reported Discover videos</span>
            <ChevronRight size={14} className="text-secondary" />
          </Link>
        </Section>
      )}

      <Section title="About & support">
        <ExternalRow label="Terms of Service" href="/terms" />
        <ExternalRow label="Privacy Policy" href="/privacy" />
        <ExternalRow label="Help & support" href="/support" />
        <ExternalRow label="Contact Support" href="mailto:support@lyoai.app" />
      </Section>

      <section className="rounded-2xl border border-red-400/25 bg-red-500/[0.05] px-5 py-4">
        <div className="flex items-start gap-3">
          <Trash2 size={17} className="mt-0.5 shrink-0 text-red-300" />
          <div className="min-w-0 flex-1">
            <h2 className="text-sm font-semibold text-red-100">Delete account</h2>
            <p className="mt-1 text-sm leading-relaxed text-white/55">
              Permanently delete your LYO account and everything in it: your profile, posts, videos, messages, AI chats and learning progress.
            </p>
            {!confirmingDelete ? (
              <button
                type="button"
                onClick={() => {
                  setDeleteError(null);
                  setConfirmingDelete(true);
                }}
                className="mt-3 rounded-xl border border-red-400/40 px-4 py-2 text-sm font-semibold text-red-200 transition hover:bg-red-500/10"
              >
                Delete account
              </button>
            ) : (
              <div role="alertdialog" aria-labelledby="delete-account-title" className="mt-3 rounded-xl border border-red-400/30 bg-black/30 p-4">
                <p id="delete-account-title" className="flex items-center gap-2 text-sm font-bold text-red-100">
                  <AlertTriangle size={15} className="shrink-0" />
                  This is permanent and cannot be undone.
                </p>
                <p className="mt-2 text-sm leading-relaxed text-white/60">
                  Your account and all of its data will be deleted for good, on every device. You will be signed out.
                </p>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => void confirmDeleteAccount()}
                    disabled={deleting}
                    className="rounded-xl bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {deleting ? 'Deleting…' : 'Delete my account permanently'}
                  </button>
                  <button
                    type="button"
                    onClick={() => setConfirmingDelete(false)}
                    disabled={deleting}
                    className="rounded-xl px-4 py-2 text-sm font-semibold text-white/70 transition hover:bg-white/5 disabled:opacity-60"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
            {deleteError && <p role="alert" className="mt-3 text-sm text-red-300">{deleteError}</p>}
          </div>
        </div>
      </section>
    </motion.div>
  );
}
