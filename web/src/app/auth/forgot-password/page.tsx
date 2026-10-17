'use client';

import { useState } from 'react';
import Link from 'next/link';
import { AlertCircle, Mail } from 'lucide-react';
import { api } from '@/lib/api';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [pending, setPending] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    setPending(true);
    setError('');
    try {
      await api.auth.requestPasswordReset(email.trim().toLowerCase());
      setSubmitted(true);
    } catch (reason) {
      const message = reason instanceof Error ? reason.message : '';
      setError(message || 'Password recovery is temporarily unavailable. Please try again later.');
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0a0a0f] px-4 py-12 text-white">
      <div className="w-full max-w-md space-y-6 rounded-3xl border border-white/10 bg-[#171720] p-8 shadow-2xl">
        <div className="space-y-2 text-center">
          <h1 className="text-2xl font-bold">Reset your LYO password</h1>
          <p className="text-sm text-gray-300">
            {submitted
              ? 'If an account exists with this email, you will receive a reset link. Check your inbox and spam folder.'
              : 'Enter your email. If you have a LYO account, we will email you a secure reset link.'}
          </p>
        </div>

        {!submitted && (
          <form onSubmit={submit} className="space-y-4">
            <label className="block space-y-2 text-sm font-semibold" htmlFor="recovery-email">
              <span>Email address</span>
              <span className="flex items-center gap-2 rounded-xl border border-white/20 bg-white/5 px-3">
                <Mail size={18} aria-hidden="true" />
                <input
                  id="recovery-email"
                  className="w-full bg-transparent py-3 outline-none"
                  type="email"
                  autoComplete="email"
                  required
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="you@example.com"
                />
              </span>
            </label>
            {error && (
              <p role="alert" className="flex items-center gap-2 text-sm text-red-300">
                <AlertCircle size={16} aria-hidden="true" />{error}
              </p>
            )}
            <button
              type="submit"
              disabled={pending}
              className="w-full rounded-xl bg-indigo-600 px-4 py-3 font-semibold hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending ? 'Sending request…' : 'Send reset link'}
            </button>
          </form>
        )}
        <Link href="/auth/login" className="block text-center text-sm text-indigo-300 hover:underline">
          Back to sign in
        </Link>
      </div>
    </main>
  );
}
