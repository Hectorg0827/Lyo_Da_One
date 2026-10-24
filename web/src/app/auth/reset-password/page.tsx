'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AlertCircle, CheckCircle2, Lock } from 'lucide-react';
import { AuthField, AuthShell, authButtonClass, authButtonStyle, authLinkClass } from '@/components/auth/AuthShell';
import { api, ApiError } from '@/lib/api';
import { passwordProblem, resetFailure, resetTokenFrom } from '@/lib/password-reset.mjs';

/**
 * Choose a new password from an emailed reset link
 * (/auth/reset-password?token=...). The link works once, for one hour.
 */
export default function ResetPasswordPage() {
  const [token, setToken] = useState<string | null>(null);
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setToken(resetTokenFrom(window.location.search));
  }, []);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!token || saving) return;
    const problem = passwordProblem(password, confirmation);
    if (problem) {
      setError(problem);
      return;
    }
    setSaving(true);
    setError('');
    try {
      await api.auth.confirmPasswordReset(token, password);
      setDone(true);
    } catch (reason) {
      setError(resetFailure(reason instanceof ApiError ? reason.status : 0, reason instanceof Error ? reason.message : null));
    } finally {
      setSaving(false);
    }
  }

  if (done) {
    return (
      <AuthShell title="Password changed" subtitle="You can log in with your new password now.">
        <div className="flex justify-center">
          <CheckCircle2 size={40} className="text-emerald-400" />
        </div>
        <Link href="/auth/login" className={`${authButtonClass} block text-center`} style={authButtonStyle}>
          Log in
        </Link>
      </AuthShell>
    );
  }

  if (token === '') {
    return (
      <AuthShell title="This link is incomplete" subtitle="It is missing the code that proves it came from us.">
        <p className="text-center text-sm text-secondary">
          Open the link from the email again, or{' '}
          <Link href="/auth/forgot-password" className={authLinkClass}>ask for a new one</Link>.
        </p>
      </AuthShell>
    );
  }

  return (
    <AuthShell title="Choose a new password" subtitle="At least 8 characters.">
      {error && (
        <div role="alert" className="space-y-1 rounded-xl px-4 py-3 text-sm" style={{ background: 'rgba(239,68,68,0.12)', border: '1px solid rgba(239,68,68,0.25)', color: '#ef4444' }}>
          <p className="flex items-center gap-2">
            <AlertCircle size={15} className="shrink-0" />
            {error}
          </p>
          {error.includes('Ask for a new one') && (
            <Link href="/auth/forgot-password" className={authLinkClass}>Ask for a new link</Link>
          )}
        </div>
      )}
      <form onSubmit={submit} className="space-y-4">
        <AuthField label="New password" type="password" value={password} onChange={setPassword} autoComplete="new-password" icon={Lock} />
        <AuthField label="Repeat it" type="password" value={confirmation} onChange={setConfirmation} autoComplete="new-password" icon={Lock} />
        <button type="submit" disabled={saving || token === null} className={authButtonClass} style={authButtonStyle}>
          {saving ? 'Saving…' : 'Save new password'}
        </button>
      </form>
    </AuthShell>
  );
}
