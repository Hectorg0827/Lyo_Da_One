'use client';

import { useState } from 'react';
import Link from 'next/link';
import { AlertCircle, Mail, MailCheck } from 'lucide-react';
import { AuthField, AuthShell, authButtonClass, authButtonStyle, authLinkClass } from '@/components/auth/AuthShell';
import { api, ApiError } from '@/lib/api';
import { resetFailure } from '@/lib/password-reset.mjs';

/**
 * Ask for a password reset link. The API answers the same whether or not
 * the email has an account, so this page always says to check the inbox.
 */
export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState<string | null>(null);
  const [error, setError] = useState('');

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!email.trim() || sending) return;
    setSending(true);
    setError('');
    try {
      const result = await api.auth.requestPasswordReset(email.trim());
      setSent(result.message);
    } catch (reason) {
      setError(resetFailure(reason instanceof ApiError ? reason.status : 0, reason instanceof Error ? reason.message : null));
    } finally {
      setSending(false);
    }
  }

  if (sent) {
    return (
      <AuthShell title="Check your email" subtitle={email.trim()}>
        <div className="flex items-start gap-3 rounded-xl px-4 py-3 text-sm text-primary" style={{ background: 'rgba(99,102,241,0.12)' }}>
          <MailCheck size={18} className="mt-0.5 shrink-0 text-[#a78bfa]" />
          <p>
            {sent} If it doesn&apos;t arrive in a few minutes, look in your spam folder.
          </p>
        </div>
        <p className="text-center text-sm text-secondary">
          <Link href="/auth/login" className={authLinkClass}>Back to log in</Link>
        </p>
      </AuthShell>
    );
  }

  return (
    <AuthShell title="Forgot your password?" subtitle="We'll email you a link to choose a new one.">
      {error && (
        <div role="alert" className="flex items-center gap-2 rounded-xl px-4 py-3 text-sm" style={{ background: 'rgba(239,68,68,0.12)', border: '1px solid rgba(239,68,68,0.25)', color: '#ef4444' }}>
          <AlertCircle size={15} className="shrink-0" />
          {error}
        </div>
      )}
      <form onSubmit={submit} className="space-y-4">
        <AuthField label="Email" type="email" value={email} onChange={setEmail} autoComplete="email" icon={Mail} />
        <button type="submit" disabled={sending || !email.trim()} className={authButtonClass} style={authButtonStyle}>
          {sending ? 'Sending…' : 'Send reset link'}
        </button>
      </form>
      <p className="text-center text-sm text-secondary">
        Remembered it? <Link href="/auth/login" className={authLinkClass}>Log in</Link>
      </p>
    </AuthShell>
  );
}
